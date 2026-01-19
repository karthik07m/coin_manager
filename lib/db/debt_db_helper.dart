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
      version: 2,
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
      // Add recurring debt columns
      await db.execute(
          'ALTER TABLE $debtsTable ADD COLUMN $columnIsRecurring INTEGER DEFAULT 0');
      await db.execute(
          'ALTER TABLE $debtsTable ADD COLUMN $columnRecurringAmount REAL');
    }
  }

  // ===== DEBT OPERATIONS =====

  Future<int> insertDebt(Debt debt) async {
    var dbClient = await database;
    try {
      return await dbClient.insert(debtsTable, debt.toMap());
    } catch (e) {
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

  Future<int> insertPayment(DebtPayment payment) async {
    var dbClient = await database;
    try {
      return await dbClient.insert(paymentsTable, payment.toMap());
    } catch (e) {
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
      return [];
    }
  }

  Future<int> deletePayment(String id) async {
    var dbClient = await database;
    try {
      return await dbClient.delete(paymentsTable,
          where: '$paymentColumnId = ?', whereArgs: [id]);
    } catch (e) {
      return -1;
    }
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
      return 0;
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
