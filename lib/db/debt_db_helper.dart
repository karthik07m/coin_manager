import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/debt.dart';
import '../models/debt_payment.dart';

class DebtDBHelper {
  static final DebtDBHelper _instance = DebtDBHelper._internal();
  factory DebtDBHelper() => _instance;
  static Database? _db;

  DebtDBHelper._internal();

  @visibleForTesting
  Future<Database> openInMemoryDatabaseForTests() async {
    await _db?.close();
    _db = await openDatabase(inMemoryDatabasePath,
        version: 4, onCreate: _onCreate, singleInstance: false);
    return _db!;
  }

  @visibleForTesting
  static Future<void> resetForTests() async {
    await _db?.close();
    _db = null;
  }

  // Debts table
  final String debtsTable = 'debts';
  final String columnId = 'id';
  final String columnTitle = 'title';
  final String columnAmount = 'amount';
  final String columnAmountPaid = 'amount_paid';
  final String columnDebtorName = 'debtor_name';
  final String columnIsLiability = 'is_liability';
  final String columnDueDate = 'due_date';
  final String columnInterestRate = 'interest_rate';
  final String columnNotes = 'notes';
  final String columnIsRecurring = 'is_recurring';
  final String columnRecurringAmount = 'recurring_amount';
  final String columnTransactionId = 'transaction_id';
  final String columnAccountId = 'account_id';
  final String columnStatus = 'status';
  final String columnCreatedOn = 'created_on';
  final String columnModifiedOn = 'modified_on';

  // Payments table
  final String paymentsTable = 'debt_payments';
  final String paymentColumnId = 'id';
  final String paymentColumnDebtId = 'debt_id';
  final String paymentColumnAmount = 'amount';
  final String paymentColumnPaymentDate = 'payment_date';
  final String paymentColumnNotes = 'notes';
  final String paymentColumnTransactionId = 'transaction_id';
  final String paymentColumnCreatedOn = 'created_on';

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'debts.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  void _onCreate(Database db, int version) async {
    // Create debts table
    await db.execute('''
      CREATE TABLE $debtsTable(
        $columnId TEXT PRIMARY KEY,
        $columnTitle TEXT NOT NULL,
        $columnAmount REAL NOT NULL,
        $columnAmountPaid REAL DEFAULT 0,
        $columnDebtorName TEXT NOT NULL,
        $columnIsLiability INTEGER NOT NULL,
        $columnDueDate TEXT,
        $columnInterestRate REAL,
        $columnNotes TEXT,
        $columnIsRecurring INTEGER DEFAULT 0,
        $columnRecurringAmount REAL,
        $columnTransactionId TEXT,
        $columnAccountId INTEGER,
        $columnStatus INTEGER NOT NULL,
        $columnCreatedOn TEXT NOT NULL,
        $columnModifiedOn TEXT NOT NULL
      )
    ''');

    // Create debt_payments table
    await db.execute('''
      CREATE TABLE $paymentsTable(
        $paymentColumnId TEXT PRIMARY KEY,
        $paymentColumnDebtId TEXT NOT NULL,
        $paymentColumnAmount REAL NOT NULL,
        $paymentColumnPaymentDate TEXT NOT NULL,
        $paymentColumnNotes TEXT,
        $paymentColumnTransactionId TEXT,
        $paymentColumnCreatedOn TEXT NOT NULL,
        FOREIGN KEY ($paymentColumnDebtId) REFERENCES $debtsTable($columnId) ON DELETE CASCADE
      )
    ''');

    // Create index for faster queries
    await db.execute('''
      CREATE INDEX idx_debt_id ON $paymentsTable($paymentColumnDebtId)
    ''');
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations
    if (oldVersion < 2) {
      // Check if columns already exist before adding
      try {
        await db.execute(
            'ALTER TABLE $debtsTable ADD COLUMN $columnIsRecurring INTEGER DEFAULT 0');
      } catch (e) {
        debugPrint('DebtDB error: $e');
        // Column might already exist, check and continue
        debugPrint('Note: $columnIsRecurring column might already exist');
      }

      try {
        await db.execute(
            'ALTER TABLE $debtsTable ADD COLUMN $columnRecurringAmount REAL');
      } catch (e) {
        debugPrint('DebtDB error: $e');
        // Column might already exist, check and continue
        debugPrint('Note: $columnRecurringAmount column might already exist');
      }
    }

    if (oldVersion < 3) {
      // Link debts and settlements to transactions (Cashew-style loans).
      try {
        await db.execute(
            'ALTER TABLE $debtsTable ADD COLUMN $columnTransactionId TEXT');
      } catch (e) {
        debugPrint('Note: $columnTransactionId column might already exist');
      }
      try {
        await db.execute(
            'ALTER TABLE $paymentsTable ADD COLUMN $paymentColumnTransactionId TEXT');
      } catch (e) {
        debugPrint(
            'Note: payment $paymentColumnTransactionId column might already exist');
      }
    }

    if (oldVersion < 4) {
      // Link a debt to the account its loan was booked against.
      try {
        await db.execute(
            'ALTER TABLE $debtsTable ADD COLUMN $columnAccountId INTEGER');
      } catch (e) {
        debugPrint('Note: $columnAccountId column might already exist');
      }
    }
  }

  // ===== DEBT OPERATIONS =====

  Future<int> insertDebt(Debt debt) async {
    var dbClient = await database;
    try {
      return await dbClient.insert(debtsTable, debt.toMap());
    } catch (e) {
      debugPrint('DebtDB error: $e');
      return -1;
    }
  }

  Future<List<Debt>> getDebts() async {
    var dbClient = await database;
    try {
      final List<Map<String, dynamic>> debts =
          await dbClient.query(debtsTable, orderBy: '$columnModifiedOn DESC');
      return debts.map((map) => Debt.fromMap(map)).toList();
    } catch (e) {
      debugPrint('DebtDB error: $e');
      return [];
    }
  }

  Future<Debt?> getDebtById(String id) async {
    var dbClient = await database;
    try {
      List<Map<String, dynamic>> maps = await dbClient.query(
        debtsTable,
        where: '$columnId = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return Debt.fromMap(maps.first);
      }
    } catch (e) {
      debugPrint('DebtDB error: $e');
      // Return null if something goes wrong
    }
    return null;
  }

  Future<int> updateDebt(Debt debt) async {
    var dbClient = await database;
    try {
      return await dbClient.update(debtsTable, debt.toMap(),
          where: '$columnId = ?', whereArgs: [debt.id]);
    } catch (e) {
      debugPrint('DebtDB error: $e');
      return -1;
    }
  }

  Future<int> deleteDebt(String id) async {
    var dbClient = await database;
    try {
      // Delete associated payments first
      await dbClient.delete(paymentsTable,
          where: '$paymentColumnDebtId = ?', whereArgs: [id]);
      // Delete the debt
      return await dbClient
          .delete(debtsTable, where: '$columnId = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('DebtDB error: $e');
      return -1;
    }
  }

  Future<List<Debt>> getDebtsByType({required bool isLiability}) async {
    var dbClient = await database;
    try {
      final List<Map<String, dynamic>> debts = await dbClient.query(
        debtsTable,
        where: '$columnIsLiability = ?',
        whereArgs: [isLiability ? 1 : 0],
        orderBy: '$columnDueDate ASC, $columnModifiedOn DESC',
      );
      return debts.map((map) => Debt.fromMap(map)).toList();
    } catch (e) {
      debugPrint('DebtDB error: $e');
      return [];
    }
  }

  Future<List<Debt>> getDebtsByStatus({required DebtStatus status}) async {
    var dbClient = await database;
    try {
      final List<Map<String, dynamic>> debts = await dbClient.query(
        debtsTable,
        where: '$columnStatus = ?',
        whereArgs: [status.index],
        orderBy: '$columnDueDate ASC, $columnModifiedOn DESC',
      );
      return debts.map((map) => Debt.fromMap(map)).toList();
    } catch (e) {
      debugPrint('DebtDB error: $e');
      return [];
    }
  }

  Future<List<Debt>> getActiveDebts() async {
    return await getDebtsByStatus(status: DebtStatus.active);
  }

  Future<List<Debt>> getOverdueDebts() async {
    return await getDebtsByStatus(status: DebtStatus.overdue);
  }

  // ===== PAYMENT OPERATIONS =====

  /// Every transaction booked from the Debt Tracker, with the debt it belongs
  /// to. Loan bookings sit on the debt row, repayments on the payment row.
  Future<List<Map<String, dynamic>>> getTransactionLinks() async {
    final db = await database;
    return db.rawQuery('''
      SELECT d.transaction_id AS transaction_id, d.id AS debt_id,
             d.debtor_name AS debtor_name, d.is_liability AS is_liability,
             0 AS is_payment
      FROM $debtsTable d WHERE d.transaction_id IS NOT NULL
      UNION ALL
      SELECT p.transaction_id, d.id, d.debtor_name, d.is_liability, 1
      FROM $paymentsTable p JOIN $debtsTable d ON d.id = p.$paymentColumnDebtId
      WHERE p.transaction_id IS NOT NULL
    ''');
  }

  /// Called when a transaction is deleted anywhere in the app. A loan booking
  /// leaves its debt in place but unbooked; a repayment is reversed so the
  /// debt balance matches the money that actually moved. No-op if unlinked.
  Future<void> detachTransaction(String transactionId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
          debtsTable, {columnTransactionId: null, columnAccountId: null},
          where: '$columnTransactionId = ?', whereArgs: [transactionId]);
      final payments = await txn.query(paymentsTable,
          where: '$paymentColumnTransactionId = ?', whereArgs: [transactionId]);
      for (final row in payments) {
        final payment = DebtPayment.fromMap(row);
        await txn.delete(paymentsTable,
            where: '$paymentColumnId = ?', whereArgs: [payment.id]);
        final rows = await txn.query(debtsTable,
            where: '$columnId = ?', whereArgs: [payment.debtId]);
        if (rows.isEmpty) continue;
        final debt = Debt.fromMap(rows.single);
        debt.amountPaid =
            (debt.amountPaid - payment.amount).clamp(0, double.infinity);
        debt.updateStatus();
        debt.modifiedOn = DateTime.now();
        await txn.update(debtsTable, debt.toMap(),
            where: '$columnId = ?', whereArgs: [debt.id]);
      }
    });
  }

  /// A transaction can represent one loan or one repayment, never both.
  Future<Set<String>> getLinkedTransactionIds() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT transaction_id FROM debts WHERE transaction_id IS NOT NULL
      UNION
      SELECT transaction_id FROM debt_payments WHERE transaction_id IS NOT NULL
    ''');
    return rows.map((row) => row['transaction_id'] as String).toSet();
  }

  /// Validate against the stored balance and commit the payment and balance
  /// together. A rejected/duplicate payment must leave neither half behind.
  Future<bool> recordPayment(DebtPayment payment) async {
    if (!payment.amount.isFinite || payment.amount <= 0) return false;
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(debtsTable,
          where: '$columnId = ?', whereArgs: [payment.debtId]);
      if (rows.isEmpty) return false;
      final debt = Debt.fromMap(rows.single);
      if (payment.amount > debt.getRemainingAmount() + 0.005) return false;
      if (payment.transactionId != null) {
        final links = await txn.rawQuery('''
          SELECT id FROM debts WHERE transaction_id = ?
          UNION ALL
          SELECT id FROM debt_payments WHERE transaction_id = ?
        ''', [payment.transactionId, payment.transactionId]);
        if (links.isNotEmpty) return false;
      }
      await txn.insert(paymentsTable, payment.toMap());
      debt.amountPaid += payment.amount;
      debt.updateStatus();
      debt.modifiedOn = DateTime.now();
      await txn.update(debtsTable, debt.toMap(),
          where: '$columnId = ?', whereArgs: [debt.id]);
      return true;
    });
  }

  Future<int> insertPayment(DebtPayment payment) async {
    var dbClient = await database;
    try {
      return await dbClient.insert(paymentsTable, payment.toMap());
    } catch (e) {
      debugPrint('DebtDB error: $e');
      return -1;
    }
  }

  Future<List<DebtPayment>> getPaymentsByDebtId(String debtId) async {
    var dbClient = await database;
    try {
      final List<Map<String, dynamic>> payments = await dbClient.query(
        paymentsTable,
        where: '$paymentColumnDebtId = ?',
        whereArgs: [debtId],
        orderBy: '$paymentColumnPaymentDate DESC',
      );
      return payments.map((map) => DebtPayment.fromMap(map)).toList();
    } catch (e) {
      debugPrint('DebtDB error: $e');
      return [];
    }
  }

  Future<int> deletePayment(String id) async {
    var dbClient = await database;
    try {
      return await dbClient.delete(paymentsTable,
          where: '$paymentColumnId = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('DebtDB error: $e');
      return -1;
    }
  }

  Future<DebtPayment?> getPaymentById(String id) async {
    var dbClient = await database;
    try {
      List<Map<String, dynamic>> maps = await dbClient.query(
        paymentsTable,
        where: '$paymentColumnId = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return DebtPayment.fromMap(maps.first);
      }
    } catch (e) {
      debugPrint('DebtDB error: $e');
    }
    return null;
  }

  // ===== STATISTICS =====

  Future<double> getTotalByType({required bool isLiability}) async {
    var dbClient = await database;
    try {
      String query = '''
        SELECT SUM($columnAmount - $columnAmountPaid) AS total 
        FROM $debtsTable 
        WHERE $columnIsLiability = ? AND $columnStatus != ?
      ''';
      List<Map<String, dynamic>> result = await dbClient
          .rawQuery(query, [isLiability ? 1 : 0, DebtStatus.paid.index]);

      if (result.isNotEmpty && result.first['total'] != null) {
        return result.first['total'] as double;
      }
      return 0.0;
    } catch (e) {
      debugPrint('DebtDB error: $e');
      return 0.0;
    }
  }

  Future<double> getTotalLiabilities() async {
    return await getTotalByType(isLiability: true);
  }

  Future<double> getTotalReceivables() async {
    return await getTotalByType(isLiability: false);
  }

  Future<int> getActiveDebtCount() async {
    var dbClient = await database;
    try {
      String query = '''
        SELECT COUNT(*) as count 
        FROM $debtsTable 
        WHERE $columnStatus = ?
      ''';
      List<Map<String, dynamic>> result =
          await dbClient.rawQuery(query, [DebtStatus.active.index]);

      if (result.isNotEmpty && result.first['count'] != null) {
        return result.first['count'] as int;
      }
      return 0;
    } catch (e) {
      debugPrint('DebtDB error: $e');
      return 0;
    }
  }

  Future<void> close() async {
    var dbClient = await database;
    try {
      await dbClient.close();
    } catch (e) {
      debugPrint('DebtDB error: $e');
      // Ignore errors on close
    }
  }
}
