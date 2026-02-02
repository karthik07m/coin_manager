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
  final String columnReceiptId = 'receipt_id';

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'transactions.db');
    return await openDatabase(
      path,
      version: 5,
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
        $columnReceiptId TEXT
      )
    ''');

    // Create accounts table with initial_balance
    await db.execute('''
      CREATE TABLE accounts(
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
  }

  Future<int> insertTransaction(trans_model.Transaction transaction) async {
    var dbClient = await database;
    try {
      return await dbClient.insert(tableName, transaction.toMap());
    } catch (e) {
      return -1;
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
      return -1;
    }
  }

  Future<int> deleteTransaction(String id) async {
    var dbClient = await database;
    try {
      return await dbClient
          .delete(tableName, where: '$columnId = ?', whereArgs: [id]);
    } catch (e) {
      return -1;
    }
  }

  /// Delete all future recurring instances of a transaction
  /// This finds all recurring transactions that match the given transaction's
  /// title, category, and amount, and deletes those with future dates
  Future<int> deleteFutureRecurringInstances(
      trans_model.Transaction transaction) async {
    var dbClient = await database;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Delete all recurring transactions that match this one and are in the future
      return await dbClient.delete(
        tableName,
        where:
            '$columnIsRecurring = 1 AND $columnTitle = ? AND $columnCategoryId = ? AND $columnAmount = ? AND $columnDate > ?',
        whereArgs: [
          transaction.title,
          transaction.categoryId,
          transaction.amount,
          today.toIso8601String(),
        ],
      );
    } catch (e) {
      debugPrint('Error deleting future recurring instances: $e');
      return -1;
    }
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
      return [];
    }
  }

  Future<List<trans_model.Transaction>> getRecurringTransactions() async {
    var dbClient = await database;
    try {
      final List<Map<String, dynamic>> transactions = await dbClient.query(
        tableName,
        where: '$columnIsRecurring = 1',
      );
      return transactions
          .map((map) => trans_model.Transaction.fromMap(map))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<trans_model.Transaction>>
      getUpcomingRecurringTransactions() async {
    var dbClient = await database;
    try {
      // Get current date range to show upcoming transactions from tomorrow through next month
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);

      // Show upcoming from tomorrow through end of next month
      final endOfNextMonth = DateTime(now.year, now.month + 2, 0);

      final List<Map<String, dynamic>> transactions = await dbClient.query(
        tableName,
        where:
            '$columnIsRecurring = 1 AND $columnIsExpense = 1 AND $columnDate >= ? AND $columnDate <= ?',
        whereArgs: [
          tomorrow.toIso8601String(),
          endOfNextMonth.toIso8601String()
        ],
        orderBy: '$columnDate ASC',
        limit: 5, // Limit to top 5 upcoming payments
      );
      return transactions
          .map((map) => trans_model.Transaction.fromMap(map))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get ALL upcoming recurring transactions (no limit) for full-screen view
  Future<List<trans_model.Transaction>>
      getAllUpcomingRecurringTransactions() async {
    var dbClient = await database;
    try {
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);

      // Show upcoming from tomorrow through end of next month
      final endOfNextMonth = DateTime(now.year, now.month + 2, 0);

      final List<Map<String, dynamic>> transactions = await dbClient.query(
        tableName,
        where:
            '$columnIsRecurring = 1 AND $columnIsExpense = 1 AND $columnDate >= ? AND $columnDate <= ?',
        whereArgs: [
          tomorrow.toIso8601String(),
          endOfNextMonth.toIso8601String()
        ],
        orderBy: '$columnDate ASC',
        // No limit - return all upcoming transactions
      );
      return transactions
          .map((map) => trans_model.Transaction.fromMap(map))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> close() async {
    var dbClient = await database;
    try {
      await dbClient.close();
    } catch (e) {
      // Ignore errors on close
    }
  }
}
