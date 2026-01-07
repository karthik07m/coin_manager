import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budget_values',
      where: 'category_name = ? AND month_key = ?',
      whereArgs: [categoryName, month],
    );

    if (maps.isNotEmpty) {
      return maps.first['amount'] as double;
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
    final List<Map<String, dynamic>> maps = await db.query(
      'budget_totals',
      where: 'month_key = ?',
      whereArgs: [month],
    );

    if (maps.isNotEmpty) {
      return maps.first['total_amount'] as double;
    }
    return 0.0;
  }

  // Get All Budgets for a Month
  Future<Map<String, double>> getAllBudgetsForMonth(String month) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budget_values',
      where: 'month_key = ?',
      whereArgs: [month],
    );

    Map<String, double> budgets = {};
    for (var map in maps) {
      budgets[map['category_name'] as String] = map['amount'] as double;
    }
    return budgets;
  }
}
