import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../utilities/budget_period.dart';

class MonthlyBudgetDBHelper {
  static final MonthlyBudgetDBHelper _instance =
      MonthlyBudgetDBHelper._internal();
  static Database? _database;

  factory MonthlyBudgetDBHelper() {
    return _instance;
  }

  MonthlyBudgetDBHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'monthly_budget.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table for storing budget per category per month
    await db.execute('''
      CREATE TABLE budget_values(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT,
        month_key TEXT,
        amount REAL
      )
    ''');

    // Table for storing total budget per month
    await db.execute('''
      CREATE TABLE budget_totals(
        month_key TEXT PRIMARY KEY,
        total_amount REAL
      )
    ''');
  }

  String? _legacyMonthKey(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return null;

    final legacyMonth = int.tryParse(parts[1]);
    return legacyMonth?.toString();
  }

  Future<List<Map<String, dynamic>>> _queryBudgetRows(
    String categoryName,
    String month,
  ) async {
    final db = await database;
    final maps = await db.query(
      'budget_values',
      where: 'category_name = ? AND month_key = ?',
      whereArgs: [categoryName, month],
    );

    if (maps.isNotEmpty) return maps;

    final legacyKey = _legacyMonthKey(month);
    if (legacyKey == null) return maps;

    return db.query(
      'budget_values',
      where: 'category_name = ? AND month_key = ?',
      whereArgs: [categoryName, legacyKey],
    );
  }

  // Insert or Update Budget for a Category
  Future<void> setBudget(
      String categoryName, String month, double amount) async {
    final db = await database;

    // Check if entry exists
    final List<Map<String, dynamic>> maps = await db.query(
      'budget_values',
      where: 'category_name = ? AND month_key = ?',
      whereArgs: [categoryName, month],
    );

    if (maps.isNotEmpty) {
      await db.update(
        'budget_values',
        {'amount': amount},
        where: 'category_name = ? AND month_key = ?',
        whereArgs: [categoryName, month],
      );
    } else {
      await db.insert(
        'budget_values',
        {'category_name': categoryName, 'month_key': month, 'amount': amount},
      );
    }
  }

  // Get Budget for a Category
  Future<double> getBudget(String categoryName, String month) async {
    final maps = await _queryBudgetRows(categoryName, month);

    if (maps.isNotEmpty) {
      return (maps.first['amount'] as num).toDouble();
    }
    return 0.0;
  }

  // Insert or Update Total Monthly Budget
  Future<void> setTotalBudget(String month, double amount) async {
    final db = await database;
    await db.insert(
      'budget_totals',
      {'month_key': month, 'total_amount': amount},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get Total Monthly Budget
  Future<double> getTotalBudget(String month) async {
    final db = await database;
    var maps = await db.query(
      'budget_totals',
      where: 'month_key = ?',
      whereArgs: [month],
    );

    final legacyKey = _legacyMonthKey(month);
    if (maps.isEmpty && legacyKey != null) {
      maps = await db.query(
        'budget_totals',
        where: 'month_key = ?',
        whereArgs: [legacyKey],
      );
    }

    if (maps.isNotEmpty) {
      return (maps.first['total_amount'] as num).toDouble();
    }
    return 0.0;
  }

  // Get All Budgets for a Month
  Future<Map<String, double>> getAllBudgetsForMonth(String month) async {
    final db = await database;
    var maps = await db.query(
      'budget_values',
      where: 'month_key = ?',
      whereArgs: [month],
    );

    final legacyKey = _legacyMonthKey(month);
    if (maps.isEmpty && legacyKey != null) {
      maps = await db.query(
        'budget_values',
        where: 'month_key = ?',
        whereArgs: [legacyKey],
      );
    }

    final budgets = <String, double>{};
    for (var map in maps) {
      budgets[map['category_name'] as String] =
          (map['amount'] as num).toDouble();
    }
    return budgets;
  }

  // Copy Budget to Next Month
  Future<void> copyBudgetToNextMonth(String currentMonth) async {
    final currentParts = currentMonth.split('-');
    final currentDate = currentParts.length == 2
        ? DateTime(
            int.parse(currentParts[0]),
            int.parse(currentParts[1]),
            1,
          )
        : DateTime(DateTime.now().year, int.parse(currentMonth), 1);
    final nextMonth = BudgetPeriod.keyFor(BudgetPeriod.nextMonth(currentDate));

    // Get current month's total budget
    final totalBudget = await getTotalBudget(currentMonth);

    // Get all category budgets for current month
    final categoryBudgets = await getAllBudgetsForMonth(currentMonth);

    // Copy total budget to next month
    if (totalBudget > 0) {
      await setTotalBudget(nextMonth, totalBudget);
    }

    // Copy all category budgets to next month
    for (var entry in categoryBudgets.entries) {
      await setBudget(entry.key, nextMonth, entry.value);
    }
  }
}
