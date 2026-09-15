import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transaction.dart' as trans_model;
import 'account_db_helper.dart';

class TransactionDBHelper {
  static final TransactionDBHelper _instance = TransactionDBHelper._internal();
  factory TransactionDBHelper() => _instance;
  static Database? _db;

  TransactionDBHelper._internal();

  final String tableName = 'transactions';
  final String columnId = 'id';
  final String columnTitle = 'title';
  final String columnAmount = 'amount';
  final String columnCategoryId = 'category_id';
  final String columnDate = 'date';
  final String columnCreatedOn = 'created_on';
  final String columnModifiedOn = 'modified_on';
  final String columnIsExpense = 'is_expense';

  final String columnIsRecurring = 'is_recurring';
  final String columnRecurrenceId = 'recurrence_id';
  final String columnReceiptId = 'receipt_id';
  final String columnTransferAccountId = 'transfer_account_id';

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }
    _db = await _initDB();
    return _db!;
  }

  /// Opens an in-memory database using the real schema and migrations, so
  /// balance and budget math can be exercised in tests without a device.
  /// Tests must set `databaseFactory = databaseFactoryFfi` first.
  @visibleForTesting
  Future<Database> openInMemoryDatabaseForTests() async {
    await _db?.close();
    _db = await openDatabase(
      inMemoryDatabasePath,
      version: 12,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  /// Drops the cached handle so each test starts from a clean database.
  @visibleForTesting
  static Future<void> resetForTests() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'transactions.db');
    return await openDatabase(
      path,
      version: 12,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  void _onCreate(Database db, int version) async {
    // Create transactions table
    await db.execute('''
      CREATE TABLE $tableName(
        $columnId TEXT PRIMARY KEY,
        $columnTitle TEXT,
        $columnAmount REAL,
        $columnCategoryId INTEGER,
        account_id INTEGER DEFAULT 1,
        $columnDate TEXT,
        $columnCreatedOn TEXT,
        $columnModifiedOn TEXT,
        $columnIsExpense INTEGER,
        $columnIsRecurring INTEGER,
        $columnRecurrenceId TEXT,
        $columnReceiptId TEXT,
        $columnTransferAccountId INTEGER
      )
    ''');

    // Create accounts table with initial_balance
    await db.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        type TEXT DEFAULT '',
        initial_balance REAL DEFAULT 0.0,
        credit_limit REAL,
        currency TEXT DEFAULT '',
        is_default INTEGER DEFAULT 0,
        created_on TEXT NOT NULL,
        modified_on TEXT NOT NULL
      )
    ''');

    // Activity/audit log (read-only history of data changes)
    await db.execute('''
      CREATE TABLE activity_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT,
        entity TEXT,
        title TEXT,
        amount REAL,
        timestamp TEXT
      )
    ''');

    // Tombstones for deleted recurring instances: a series never regenerates
    // an instance for a (recurrence_id, year, month) the user deleted.
    await db.execute('''
      CREATE TABLE recurring_skips(
        recurrence_id TEXT NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        PRIMARY KEY (recurrence_id, year, month)
      )
    ''');

    // Create default accounts
    await AccountDBHelper.createDefaultAccounts(db);
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE $tableName ADD COLUMN $columnIsRecurring INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db
          .execute('ALTER TABLE $tableName ADD COLUMN $columnReceiptId TEXT');
    }
    if (oldVersion < 4) {
      // Add account_id column to transactions
      try {
        await db.execute(
            'ALTER TABLE $tableName ADD COLUMN account_id INTEGER DEFAULT 1');
      } catch (e) {
        debugPrint('TransactionDB error: $e');
        // Column might already exist
        debugPrint('Note: account_id column might already exist');
      }

      // Create accounts table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS accounts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          icon TEXT NOT NULL,
          color TEXT NOT NULL,
          balance REAL DEFAULT 0.0,
          is_default INTEGER DEFAULT 0,
          created_on TEXT NOT NULL,
          modified_on TEXT NOT NULL
        )
      ''');

      // Check if accounts table is empty before creating default accounts
      final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM accounts'));
      if (count == 0) {
        await AccountDBHelper.createDefaultAccounts(db);
      }
    }

    if (oldVersion < 5) {
      // Migrate balance column to initial_balance
      try {
        // Check if initial_balance column already exists
        final columns = await db.rawQuery('PRAGMA table_info(accounts)');
        final hasInitialBalance =
            columns.any((col) => col['name'] == 'initial_balance');

        if (!hasInitialBalance) {
          // Create temp table with new schema
          await db.execute('''
            CREATE TABLE accounts_new(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              icon TEXT NOT NULL,
              color TEXT NOT NULL,
              initial_balance REAL DEFAULT 0.0,
              is_default INTEGER DEFAULT 0,
              created_on TEXT NOT NULL,
              modified_on TEXT NOT NULL
            )
          ''');

          // Copy data from old table to new
          await db.execute('''
            INSERT INTO accounts_new (id, name, icon, color, initial_balance, is_default, created_on, modified_on)
            SELECT id, name, icon, color, balance, is_default, created_on, modified_on
            FROM accounts
          ''');

          // Drop old table and rename new one
          await db.execute('DROP TABLE accounts');
          await db.execute('ALTER TABLE accounts_new RENAME TO accounts');
        }
      } catch (e) {
        debugPrint('Error migrating balance column: $e');
      }
    }

    if (oldVersion < 6) {
      try {
        await db.execute(
            'ALTER TABLE $tableName ADD COLUMN $columnRecurrenceId TEXT');
      } catch (e) {
        debugPrint('Note: recurrence_id column might already exist');
      }

      await _backfillRecurrenceIds(db);
    }

    if (oldVersion < 7) {
      // Account types (Checking / Savings / Cash / Credit Card / Investment /
      // Other), so credit cards can be treated as liabilities like real
      // finance apps. Backfill legacy rows by name.
      try {
        await db.execute("ALTER TABLE accounts ADD COLUMN type TEXT DEFAULT ''");
      } catch (e) {
        debugPrint('Note: accounts.type column might already exist');
      }
      try {
        await db.execute('''
          UPDATE accounts SET type = CASE
            WHEN lower(name) LIKE '%credit%' THEN 'credit_card'
            WHEN lower(name) LIKE '%cash%' THEN 'cash'
            WHEN lower(name) LIKE '%saving%' THEN 'savings'
            WHEN lower(name) LIKE '%invest%' THEN 'investment'
            ELSE 'checking'
          END
          WHERE type IS NULL OR type = ''
        ''');
      } catch (e) {
        debugPrint('Error backfilling account types: $e');
      }
    }

    if (oldVersion < 8) {
      // Account-to-account transfers (Cashew-style): a transfer row carries a
      // destination account id and is excluded from income/expense totals.
      try {
        await db.execute(
            'ALTER TABLE $tableName ADD COLUMN $columnTransferAccountId INTEGER');
      } catch (e) {
        debugPrint('Note: transfer_account_id column might already exist');
      }
    }

    if (oldVersion < 9) {
      // Credit limit on accounts, so credit cards can show available credit
      // (limit − owed) and a utilization bar. Null for non-credit accounts.
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN credit_limit REAL');
      } catch (e) {
        debugPrint('Note: accounts.credit_limit column might already exist');
      }
    }

    if (oldVersion < 10) {
      // Activity/audit log table.
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS activity_log(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT,
            entity TEXT,
            title TEXT,
            amount REAL,
            timestamp TEXT
          )
        ''');
      } catch (e) {
        debugPrint('Error creating activity_log table: $e');
      }
    }

    if (oldVersion < 11) {
      // Per-account currency (multi-currency support). Empty = base currency.
      try {
        await db
            .execute("ALTER TABLE accounts ADD COLUMN currency TEXT DEFAULT ''");
      } catch (e) {
        debugPrint('Note: accounts.currency column might already exist');
      }
    }

    if (oldVersion < 12) {
      // Deleted-recurring-instance tombstones, so deleting an occurrence of a
      // recurring transaction sticks across app restarts instead of being
      // silently regenerated by checkAndGenerateRecurringTransactions.
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS recurring_skips(
            recurrence_id TEXT NOT NULL,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            PRIMARY KEY (recurrence_id, year, month)
          )
        ''');
      } catch (e) {
        debugPrint('Error creating recurring_skips table: $e');
      }
    }
  }

  Future<void> _backfillRecurrenceIds(Database db) async {
    await db.execute('''
      UPDATE $tableName
      SET $columnRecurrenceId = (
        SELECT seed.$columnId
        FROM $tableName seed
        WHERE seed.$columnIsRecurring = 1
          AND seed.$columnTitle = $tableName.$columnTitle
          AND seed.$columnCategoryId = $tableName.$columnCategoryId
          AND seed.account_id = $tableName.account_id
          AND seed.$columnAmount = $tableName.$columnAmount
          AND seed.$columnIsExpense = $tableName.$columnIsExpense
        ORDER BY seed.$columnDate ASC, seed.$columnCreatedOn ASC, seed.$columnId ASC
        LIMIT 1
      )
      WHERE $columnIsRecurring = 1
        AND $columnRecurrenceId IS NULL
    ''');
  }

  Future<int> insertTransaction(trans_model.Transaction transaction) async {
    var dbClient = await database;
    try {
      return await dbClient.insert(tableName, transaction.toMap());
    } catch (e) {
      debugPrint('TransactionDB error: $e');
      return -1;
    }
  }

  /// Batch-insert transactions (CSV import). One commit for the whole set.
  Future<int> insertTransactionsBatch(
      List<trans_model.Transaction> transactions) async {
    var dbClient = await database;
    try {
      final batch = dbClient.batch();
      for (final t in transactions) {
        batch.insert(tableName, t.toMap());
      }
      await batch.commit(noResult: true);
      return transactions.length;
    } catch (e) {
      debugPrint('TransactionDB insertTransactionsBatch error: $e');
      return 0;
    }
  }

  Future<List<trans_model.Transaction>> getTransactions() async {
    var dbClient = await database;
    try {
      final List<Map<String, dynamic>> transactions =
          await dbClient.query(tableName, orderBy: '$columnDate DESC');
      return transactions
          .map((map) => trans_model.Transaction.fromMap(map))
          .toList();
    } catch (e) {
      debugPrint('TransactionDB error: $e');
      return [];
    }
  }

  Future<trans_model.Transaction?> getTransactionById(String id) async {
    var dbClient = await database;
    try {
      List<Map<String, dynamic>> maps = await dbClient.query(
        tableName,
        where: '$columnId = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return trans_model.Transaction.fromMap(maps.first);
      }
    } catch (e) {
      debugPrint('TransactionDB error: $e');
      // Return null if something goes wrong
    }
    return null;
  }

  Future<int> updateTransaction(trans_model.Transaction transaction) async {
    var dbClient = await database;
    try {
      return await dbClient.update(tableName, transaction.toMap(),
          where: '$columnId = ?', whereArgs: [transaction.id]);
    } catch (e) {
      debugPrint('TransactionDB error: $e');
      return -1;
    }
  }

  /// Record that the user deleted a recurring instance for this month, so
  /// generation never resurrects it.
  Future<void> insertRecurringSkip(
      String recurrenceId, int year, int month) async {
    final db = await database;
    try {
      await db.insert(
        'recurring_skips',
        {'recurrence_id': recurrenceId, 'year': year, 'month': month},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      debugPrint('insertRecurringSkip error: $e');
    }
  }

  /// Whether the user deleted this series' instance for the given month.
  Future<bool> isRecurringSkipped(
      String recurrenceId, int year, int month) async {
    final db = await database;
    try {
      final rows = await db.query(
        'recurring_skips',
        where: 'recurrence_id = ? AND year = ? AND month = ?',
        whereArgs: [recurrenceId, year, month],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (e) {
      debugPrint('isRecurringSkipped error: $e');
      return false;
    }
  }

  /// Remove all tombstones for a series (used when the user re-enables or
  /// recreates a series and wants future generation back).
  Future<void> clearRecurringSkips(String recurrenceId) async {
    final db = await database;
    try {
      await db.delete('recurring_skips',
          where: 'recurrence_id = ?', whereArgs: [recurrenceId]);
    } catch (e) {
      debugPrint('clearRecurringSkips error: $e');
    }
  }

  Future<int> deleteTransaction(String id) async {
    var dbClient = await database;
    try {
      return await dbClient
          .delete(tableName, where: '$columnId = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('TransactionDB error: $e');
      return -1;
    }
  }

  Future<int> deactivateRecurringSeries(
    trans_model.Transaction transaction, {
    String? deleteTransactionId,
  }) async {
    final dbClient = await database;
    final recurrenceId = transaction.recurrenceId ?? transaction.id;

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return await dbClient.transaction((txn) async {
        int affected = 0;

        affected += await txn.delete(
          tableName,
          where: '''
            $columnIsRecurring = 1
            AND ($columnDate > ? ${deleteTransactionId == null ? '' : 'OR $columnId = ?'})
            AND ${_recurringSeriesWhereClause()}
          ''',
          whereArgs: [
            today.toIso8601String(),
            if (deleteTransactionId != null) deleteTransactionId,
            ..._recurringSeriesWhereArgs(transaction, recurrenceId),
          ],
        );

        affected += await txn.update(
          tableName,
          {
            columnIsRecurring: 0,
            columnRecurrenceId: null,
            columnModifiedOn: DateTime.now().toIso8601String(),
          },
          where: '''
            $columnIsRecurring = 1
            AND ${_recurringSeriesWhereClause()}
          ''',
          whereArgs: _recurringSeriesWhereArgs(transaction, recurrenceId),
        );

        return affected;
      });
    } catch (e) {
      debugPrint('Error deactivating recurring series: $e');
      return -1;
    }
  }

  /// Delete all future recurring instances of a transaction series.
  /// Historical instances are preserved. The edited row can be excluded so its
  /// update does not delete itself when the edited instance is dated in future.
  Future<int> deleteFutureRecurringInstances(
    trans_model.Transaction transaction, {
    String? excludeId,
  }) async {
    var dbClient = await database;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final recurrenceId = transaction.recurrenceId ?? transaction.id;

      return await dbClient.delete(
        tableName,
        where: '''
            $columnIsRecurring = 1
            AND $columnDate > ?
            ${excludeId == null ? '' : 'AND $columnId != ?'}
            AND ${_recurringSeriesWhereClause()}
            ''',
        whereArgs: [
          today.toIso8601String(),
          if (excludeId != null) excludeId,
          ..._recurringSeriesWhereArgs(transaction, recurrenceId),
        ],
      );
    } catch (e) {
      debugPrint('Error deleting future recurring instances: $e');
      return -1;
    }
  }

  String _recurringSeriesWhereClause() {
    return '''
      (
        $columnRecurrenceId = ?
        OR $columnId = ?
        OR (
          $columnRecurrenceId IS NULL
          AND $columnTitle = ?
          AND $columnCategoryId = ?
          AND account_id = ?
          AND $columnAmount = ?
          AND $columnIsExpense = ?
        )
      )
    ''';
  }

  List<Object?> _recurringSeriesWhereArgs(
    trans_model.Transaction transaction,
    String recurrenceId,
  ) {
    return [
      recurrenceId,
      recurrenceId,
      transaction.title,
      transaction.categoryId,
      transaction.accountId,
      transaction.amount,
      transaction.isExpense ? 1 : 0,
    ];
  }

  Future<double> _getTotalAmountByPeriod({
    required bool isExpense,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var dbClient = await database;
    try {
      List<String> whereClauses = ["$columnIsExpense = ${isExpense ? 1 : 0}"];
      List<dynamic> whereArgs = [];

      if (startDate != null) {
        whereClauses.add("$columnDate >= ?");
        whereArgs.add(startDate.toIso8601String());
      }
      if (endDate != null) {
        whereClauses.add("$columnDate <= ?");
        whereArgs.add(endDate.toIso8601String());
      }

      String whereClause = whereClauses.join(' AND ');
      String query =
          "SELECT SUM($columnAmount) AS total FROM $tableName WHERE $whereClause";

      List<Map<String, dynamic>> result =
          await dbClient.rawQuery(query, whereArgs);

      if (result.isNotEmpty && result.first['total'] != null) {
        return result.first['total'] as double;
      }

      return 0.0;
    } catch (e) {
      debugPrint('TransactionDB error: $e');
      return 0.0;
    }
  }

  Future<double> getTotalExpensesByPeriod({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _getTotalAmountByPeriod(
      isExpense: true,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<double> getTotalIncomeByPeriod({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _getTotalAmountByPeriod(
      isExpense: false,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<trans_model.Transaction>> getTransactionsByType({
    bool? isExpense, // Nullable to fetch both income and expenses
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var dbClient = await database;
    try {
      List<String> whereClauses = [];
      List<dynamic> whereArgs = [];

      // Handle isExpense filter
      if (isExpense != null) {
        whereClauses.add("$columnIsExpense = ${isExpense ? 1 : 0}");
      }

      // Handle date range filter
      if (startDate != null && endDate != null) {
        whereClauses.add('$columnDate >= ? AND $columnDate <= ?');
        whereArgs
            .addAll([startDate.toIso8601String(), endDate.toIso8601String()]);
      }

      // Combine where clauses
      String? whereClause =
          whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

      final List<Map<String, dynamic>> transactions = await dbClient.query(
        tableName,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: '$columnDate DESC',
      );

      return transactions
          .map((map) => trans_model.Transaction.fromMap(map))
          .toList();
    } catch (e) {
      debugPrint('TransactionDB error: $e');
      return [];
    }
  }

  /// Returns the category most recently used for a transaction with the
  /// exact same (case-insensitive) title and expense/income type, so the
  /// form can auto-suggest it when the user re-types a familiar title.
  Future<int?> getLastCategoryIdForTitle(String title, bool isExpense) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;

    var dbClient = await database;
    try {
      final List<Map<String, dynamic>> result = await dbClient.query(
        tableName,
        columns: [columnCategoryId],
        where: 'LOWER($columnTitle) = ? AND $columnIsExpense = ?',
        whereArgs: [trimmed.toLowerCase(), isExpense ? 1 : 0],
        orderBy: '$columnDate DESC',
        limit: 1,
      );
      if (result.isNotEmpty && result.first[columnCategoryId] != null) {
        return result.first[columnCategoryId] as int;
      }
    } catch (e) {
      debugPrint('TransactionDB error: $e');
      // ignore, fall through to null
    }
    return null;
  }

  /// Category of the most recently added transaction of this type (transfers
  /// excluded), so a new entry starts where the user last filed one instead
  /// of a fixed default.
  Future<int?> getLastCategoryId(bool isExpense) async {
    var dbClient = await database;
    try {
      final result = await dbClient.query(
        tableName,
        columns: [columnCategoryId],
        where: '$columnIsExpense = ? AND $columnTransferAccountId IS NULL '
            'AND $columnCategoryId IS NOT NULL',
        whereArgs: [isExpense ? 1 : 0],
        orderBy: '$columnCreatedOn DESC',
        limit: 1,
      );
      if (result.isNotEmpty) return result.first[columnCategoryId] as int;
    } catch (e) {
      debugPrint('TransactionDB error: $e');
    }
    return null;
  }

  Future<List<trans_model.Transaction>> getRecurringTransactions() async {
    var dbClient = await database;
    try {
      // Return the oldest template row for each recurrence series. Generated
      // future instances share recurrence_id and must not become separate seeds.
      final List<Map<String, dynamic>> transactions =
          await dbClient.rawQuery('''
        SELECT t.* FROM $tableName t
        WHERE t.$columnIsRecurring = 1
          AND NOT EXISTS (
            SELECT 1 FROM $tableName older
            WHERE older.$columnIsRecurring = 1
              AND COALESCE(older.$columnRecurrenceId, older.$columnId) =
                  COALESCE(t.$columnRecurrenceId, t.$columnId)
              AND (
                older.$columnDate < t.$columnDate
                OR (
                  older.$columnDate = t.$columnDate
                  AND older.$columnCreatedOn < t.$columnCreatedOn
                )
                OR (
                  older.$columnDate = t.$columnDate
                  AND older.$columnCreatedOn = t.$columnCreatedOn
                  AND older.$columnId < t.$columnId
                )
              )
          )
      ''');
      return transactions
          .map((map) => trans_model.Transaction.fromMap(map))
          .toList();
    } catch (e) {
      debugPrint('TransactionDB error: $e');
      return [];
    }
  }

  /// Recurring entries still due before the end of this month — income as
  /// well as expenses, since both are things the user is expecting.
  Future<List<trans_model.Transaction>>
      getUpcomingRecurringTransactions() async {
    var dbClient = await database;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final firstDayOfNextMonth = DateTime(now.year, now.month + 1, 1);

      final List<Map<String, dynamic>> transactions = await dbClient.query(
        tableName,
        where:
            '$columnIsRecurring = 1 AND $columnDate >= ? AND $columnDate < ?',
        whereArgs: [
          today.toIso8601String(),
          firstDayOfNextMonth.toIso8601String()
        ],
        orderBy: '$columnDate ASC',
        limit: 5,
      );
      return transactions
          .map((map) => trans_model.Transaction.fromMap(map))
          .toList();
    } catch (e) {
      debugPrint('TransactionDB error: $e');
      return [];
    }
  }

  /// Get ALL upcoming recurring transactions (no limit) for full-screen view.
  /// Includes income as well as expenses.
  Future<List<trans_model.Transaction>>
      getAllUpcomingRecurringTransactions() async {
    var dbClient = await database;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final firstDayOfNextMonth = DateTime(now.year, now.month + 1, 1);

      final List<Map<String, dynamic>> transactions = await dbClient.query(
        tableName,
        where:
            '$columnIsRecurring = 1 AND $columnDate >= ? AND $columnDate < ?',
        whereArgs: [
          today.toIso8601String(),
          firstDayOfNextMonth.toIso8601String()
        ],
        orderBy: '$columnDate ASC',
      );
      return transactions
          .map((map) => trans_model.Transaction.fromMap(map))
          .toList();
    } catch (e) {
      debugPrint('TransactionDB error: $e');
      return [];
    }
  }

  Future<void> close() async {
    var dbClient = await database;
    try {
      await dbClient.close();
    } catch (e) {
      debugPrint('TransactionDB error: $e');
      // Ignore errors on close
    }
  }
}
