import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget_scope.dart';
import '../models/monthly_budget.dart';
import '../models/activity_log.dart';
import '../services/activity_logger.dart';
import '../db/monthly_budget_db_helper.dart';
import '../utilities/budget_period.dart';

/// One month's budget as stored: the overall figure plus the per-category
/// split. Used to seed a new month from the last one the user actually set.
class MonthBudgetSnapshot {
  final String monthKey;
  final double totalBudget;
  final Map<String, double> categoryBudgets;
  final BudgetScope scope;

  const MonthBudgetSnapshot({
    required this.monthKey,
    required this.totalBudget,
    required this.categoryBudgets,
    this.scope = BudgetScope.allExpenses,
  });

  DateTime get month {
    final parts = monthKey.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  String get label => DateFormat('MMMM yyyy').format(month);

  bool get isEmpty =>
      totalBudget <= 0 && categoryBudgets.values.every((value) => value <= 0);
}

class MonthlyBudgetProvider with ChangeNotifier {
  final List<MonthlyBudget> _monthlyBudgets =
      []; // List to store monthly budgets
  final MonthlyBudgetDBHelper _dbHelper = MonthlyBudgetDBHelper();

  List<MonthlyBudget> get monthlyBudgets => _monthlyBudgets;

  final Map<String, double> _totalBudgets = {};

  /// Per-month budget scope, cached alongside the totals so widgets can read
  /// it synchronously during build.
  final Map<String, BudgetScope> _scopes = {};

  BudgetScope getScope(String month) =>
      _scopes[month] ?? BudgetScope.allExpenses;

  /// Bumped on every budget write. Widgets holding a cached future (period
  /// history, month lists) watch this to know their data went stale.
  int _revision = 0;
  int get revision => _revision;

  double getTotalBudget(String month) => _totalBudgets[month] ?? 0.0;

  Future<double> fetchTotalBudget(String month) async {
    if (_totalBudgets.containsKey(month)) {
      return _totalBudgets[month] ?? 0.0;
    }

    final total = await _dbHelper.getTotalBudget(month);
    _totalBudgets[month] = total;
    return total;
  }

  // Initialize and load data for the current month
  Future<void> loadMonthlyData(String month) async {
    // Load Total Budget
    final total = await _dbHelper.getTotalBudget(month);
    _totalBudgets[month] = total;
    _scopes[month] = await _dbHelper.getBudgetScope(month);

    // Load Category Budgets
    final budgets = await _dbHelper.getAllBudgetsForMonth(month);

    // Drop this month's cached values first, so a category budget that was
    // cleared in the database doesn't linger in memory.
    for (final entry in _monthlyBudgets) {
      entry.budgets.remove(month);
    }

    budgets.forEach((categoryName, amount) {
      MonthlyBudget? monthlyBudget = _monthlyBudgets.firstWhere(
        (budget) => budget.categoryName == categoryName,
        orElse: () => MonthlyBudget(categoryName: categoryName),
      );
      monthlyBudget.setBudget(month, amount);
      if (!_monthlyBudgets.contains(monthlyBudget)) {
        _monthlyBudgets.add(monthlyBudget);
      }
    });

    notifyListeners();
  }

  // Method to set budget for a specific category and month
  Future<void> setBudget(
      String categoryName, String month, double budget) async {
    _cacheCategoryBudget(categoryName, month, budget);
    _revision++;
    notifyListeners(); // Notify listeners about the changes

    await _dbHelper.setBudget(categoryName, month, budget);
    ActivityLogger().updated(ActivityEntity.budget, categoryName,
        amount: budget);
  }

  void _cacheCategoryBudget(String categoryName, String month, double budget) {
    MonthlyBudget? monthlyBudget = _monthlyBudgets.firstWhere(
      (entry) => entry.categoryName == categoryName,
      orElse: () => MonthlyBudget(categoryName: categoryName),
    );

    monthlyBudget.setBudget(month, budget);

    // If the budget was newly created, add it to the list
    if (!_monthlyBudgets.contains(monthlyBudget)) {
      _monthlyBudgets.add(monthlyBudget);
    }
  }

  // Method to get budget for a specific category and month
  double getBudget(String categoryName, String month) {
    MonthlyBudget? monthlyBudget = _monthlyBudgets.firstWhere(
      (budget) => budget.categoryName == categoryName,
      orElse: () => MonthlyBudget(categoryName: categoryName),
    );

    return monthlyBudget.getBudget(month);
  }

  Future<void> setTotalBudget(String month, double amount) async {
    _totalBudgets[month] = amount;
    _revision++;
    notifyListeners();
    await _dbHelper.setTotalBudget(month, amount);
    ActivityLogger()
        .updated(ActivityEntity.budget, 'Total budget', amount: amount);
  }

  /// Saves a month's overall budget and its category split as one unit, so an
  /// edit can never land half applied. This is the write path the budget
  /// editor uses; per-category writes stay available for one-off changes.
  Future<void> saveMonthBudget({
    required String month,
    required double totalBudget,
    required Map<String, double> categoryBudgets,
    BudgetScope scope = BudgetScope.allExpenses,
  }) async {
    await _dbHelper.saveMonthBudget(
      month: month,
      totalAmount: totalBudget,
      categoryBudgets: categoryBudgets,
      scope: scope,
    );

    _totalBudgets[month] = totalBudget;
    _scopes[month] = scope;
    categoryBudgets.forEach((categoryName, amount) {
      _cacheCategoryBudget(categoryName, month, amount);
    });

    _revision++;
    notifyListeners();

    ActivityLogger().updated(
      ActivityEntity.budget,
      'Budget for ${_monthLabel(month)}',
      amount: totalBudget,
    );
  }

  /// The most recent month before [month] that has a budget on record.
  Future<MonthBudgetSnapshot?> previousMonthBudget(String month) async {
    final previousKey = await _dbHelper.latestBudgetedMonthBefore(month);
    if (previousKey == null) return null;

    return MonthBudgetSnapshot(
      monthKey: previousKey,
      totalBudget: await _dbHelper.getTotalBudget(previousKey),
      categoryBudgets: await _dbHelper.getAllBudgetsForMonth(previousKey),
      scope: await _dbHelper.getBudgetScope(previousKey),
    );
  }

  /// True when the user has actually budgeted for this month — an overall
  /// figure or at least one category.
  Future<bool> hasBudgetFor(String month) async {
    final total = await _dbHelper.getTotalBudget(month);
    if (total > 0) return true;

    final categoryBudgets = await _dbHelper.getAllBudgetsForMonth(month);
    return categoryBudgets.values.any((amount) => amount > 0);
  }

  /// Carries the last budgeted month forward into [month] when that month has
  /// nothing set yet. Returns the month it copied from, or null if it did
  /// nothing. This is what keeps every month tracked without retyping.
  Future<String?> rollOverBudget(String month) async {
    if (await hasBudgetFor(month)) return null;

    final previous = await previousMonthBudget(month);
    if (previous == null || previous.isEmpty) return null;

    await _dbHelper.copyBudget(fromMonth: previous.monthKey, toMonth: month);
    await loadMonthlyData(month);
    _revision++;
    notifyListeners();

    ActivityLogger().created(
      ActivityEntity.budget,
      'Budget carried into ${_monthLabel(month)}',
      amount: previous.totalBudget,
    );

    return previous.monthKey;
  }

  /// Copies one month's budget over another's.
  Future<void> copyBudget({
    required String fromMonth,
    required String toMonth,
  }) async {
    await _dbHelper.copyBudget(fromMonth: fromMonth, toMonth: toMonth);
    await loadMonthlyData(toMonth);
    _revision++;
    notifyListeners();

    ActivityLogger().updated(
      ActivityEntity.budget,
      'Budget copied to ${_monthLabel(toMonth)}',
      amount: getTotalBudget(toMonth),
    );
  }

  /// Resets a month back to "no budget set".
  Future<void> clearMonth(String month) async {
    await _dbHelper.clearMonth(month);

    _totalBudgets[month] = 0.0;
    _scopes.remove(month);
    for (final entry in _monthlyBudgets) {
      entry.budgets.remove(month);
    }

    _revision++;
    notifyListeners();

    ActivityLogger()
        .deleted(ActivityEntity.budget, 'Budget for ${_monthLabel(month)}');
  }

  String _monthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return monthKey;

    return DateFormat('MMMM yyyy').format(DateTime(year, month));
  }

  // Copy current month's budget to next month
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
