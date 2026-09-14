import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/budget_scope.dart';
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

  /// Opens an in-memory database using the real schema, so budget storage —
  /// including the v1 to v2 scope migration — can be tested without a device.
  /// Tests must set `databaseFactory = databaseFactoryFfi` first.
  ///
  /// Pass [path] to use a file instead, which is required for migration tests:
  /// an in-memory database is discarded when its connection closes, so it
  /// cannot be reopened at a higher version.
  @visibleForTesting
  Future<Database> openInMemoryDatabaseForTests({
    int version = 2,
    String? path,
  }) async {
    await _database?.close();
    _database = await openDatabase(
      path ?? inMemoryDatabasePath,
      version: version,
      onCreate: version == 1 ? _onCreateV1 : _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  /// The v1 schema, kept so migration tests start from what shipped rather
  /// than from a hand-written approximation.
  Future<void> _onCreateV1(Database db, int version) async {
    await db.execute('''
      CREATE TABLE budget_values(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT,
        month_key TEXT,
        amount REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE budget_totals(
        month_key TEXT PRIMARY KEY,
        total_amount REAL
      )
    ''');
  }

  /// Reopens an existing in-memory database at a higher version to exercise
  /// [_onUpgrade]. sqflite runs migrations on open, so the handle is swapped.
  @visibleForTesting
  Future<Database> reopenAtVersionForTests(String path, int version) async {
    _database = await openDatabase(
      path,
      version: version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  @visibleForTesting
  static Future<void> resetForTests() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'monthly_budget.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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
        total_amount REAL,
        scope TEXT
      )
    ''');
  }

  /// v2 adds `scope`: whether a month's budget is measured against all
  /// spending or only the categories it budgets. Existing rows keep NULL,
  /// which reads back as [BudgetScope.allExpenses] — the old behaviour.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final columns = await db.rawQuery('PRAGMA table_info(budget_totals)');
      final hasScope = columns.any((col) => col['name'] == 'scope');
      if (!hasScope) {
        await db.execute('ALTER TABLE budget_totals ADD COLUMN scope TEXT');
      }
    }
  }

  /// Canonical month key shape: `YYYY-MM`.
  static final RegExp _monthKeyPattern = RegExp(r'^\d{4}-\d{2}$');

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
    // UPDATE first, then INSERT: a replace-insert would drop the row's scope,
    // silently reverting a category-scoped budget to counting everything.
    final updated = await db.update(
      'budget_totals',
      {'total_amount': amount},
      where: 'month_key = ?',
      whereArgs: [month],
    );

    if (updated == 0) {
      await db.insert(
        'budget_totals',
        {'month_key': month, 'total_amount': amount},
      );
    }
  }

  /// How a month's budget is measured. Months saved before scopes existed
  /// read back as [BudgetScope.allExpenses].
  Future<BudgetScope> getBudgetScope(String month) async {
    final db = await database;
    var maps = await db.query(
      'budget_totals',
      columns: ['scope'],
      where: 'month_key = ?',
      whereArgs: [month],
    );

    final legacyKey = _legacyMonthKey(month);
    if (maps.isEmpty && legacyKey != null) {
      maps = await db.query(
        'budget_totals',
        columns: ['scope'],
        where: 'month_key = ?',
        whereArgs: [legacyKey],
      );
    }

    if (maps.isEmpty) return BudgetScope.allExpenses;
    return BudgetScope.fromStorage(maps.first['scope']);
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

  /// Writes a whole month in one transaction so a budget is never left half
  /// saved: either the total and every category land together, or none do.
  Future<void> saveMonthBudget({
    required String month,
    required double totalAmount,
    required Map<String, double> categoryBudgets,
    required BudgetScope scope,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.insert(
        'budget_totals',
        {
          'month_key': month,
          'total_amount': totalAmount,
          'scope': scope.storageValue,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final entry in categoryBudgets.entries) {
        final updated = await txn.update(
          'budget_values',
          {'amount': entry.value},
          where: 'category_name = ? AND month_key = ?',
          whereArgs: [entry.key, month],
        );

        if (updated == 0) {
          await txn.insert(
            'budget_values',
            {
              'category_name': entry.key,
              'month_key': month,
              'amount': entry.value,
            },
          );
        }
      }
    });
  }

  /// Every month with a budget on record, newest first. Legacy
  /// month-number-only keys are skipped — they can't be placed on a timeline.
  Future<List<String>> getBudgetedMonthKeys() async {
    final db = await database;
    final keys = <String>{};

    void collect(List<Map<String, dynamic>> rows) {
      for (final row in rows) {
        final key = row['month_key'] as String?;
        if (key != null && _monthKeyPattern.hasMatch(key)) {
          keys.add(key);
        }
      }
    }

    collect(await db.query(
      'budget_totals',
      columns: ['month_key'],
      where: 'total_amount > 0',
    ));
    collect(await db.query(
      'budget_values',
      columns: ['month_key'],
      where: 'amount > 0',
      distinct: true,
    ));

    final sorted = keys.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  /// Most recent month before [month] that has a budget, or null on a first
  /// run. Month keys are zero padded, so plain string ordering is date order.
  Future<String?> latestBudgetedMonthBefore(String month) async {
    for (final key in await getBudgetedMonthKeys()) {
      if (key.compareTo(month) < 0) return key;
    }
    return null;
  }

  /// Wipes a month back to "no budget set". Legacy rows for the same calendar
  /// month go too, otherwise the read fallback would resurrect them.
  Future<void> clearMonth(String month) async {
    final db = await database;
    final legacyKey = _legacyMonthKey(month);
    final keys = <String>[month, if (legacyKey != null) legacyKey];
    final placeholders = List.filled(keys.length, '?').join(', ');

    await db.transaction((txn) async {
      await txn.delete(
        'budget_values',
        where: 'month_key IN ($placeholders)',
        whereArgs: keys,
      );
      await txn.delete(
        'budget_totals',
        where: 'month_key IN ($placeholders)',
        whereArgs: keys,
      );
    });
  }

  /// Replaces [toMonth]'s budget with [fromMonth]'s.
  Future<void> copyBudget({
    required String fromMonth,
    required String toMonth,
  }) async {
    if (fromMonth == toMonth) return;

    final totalBudget = await getTotalBudget(fromMonth);
    final categoryBudgets = await getAllBudgetsForMonth(fromMonth);
    final scope = await getBudgetScope(fromMonth);

    await clearMonth(toMonth);
    await saveMonthBudget(
      month: toMonth,
      totalAmount: totalBudget,
      categoryBudgets: categoryBudgets,
      scope: scope,
    );
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

    await copyBudget(fromMonth: currentMonth, toMonth: nextMonth);
  }
}
