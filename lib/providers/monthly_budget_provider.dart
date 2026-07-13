import 'package:flutter/material.dart';
import '../models/monthly_budget.dart';
import '../models/activity_log.dart';
import '../services/activity_logger.dart';
import '../db/monthly_budget_db_helper.dart';
import '../utilities/budget_period.dart';

class MonthlyBudgetProvider with ChangeNotifier {
  final List<MonthlyBudget> _monthlyBudgets =
      []; // List to store monthly budgets
  final MonthlyBudgetDBHelper _dbHelper = MonthlyBudgetDBHelper();

  List<MonthlyBudget> get monthlyBudgets => _monthlyBudgets;

  final Map<String, double> _totalBudgets = {};

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

    // Load Category Budgets
    final budgets = await _dbHelper.getAllBudgetsForMonth(month);
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
    MonthlyBudget? monthlyBudget = _monthlyBudgets.firstWhere(
      (budget) => budget.categoryName == categoryName,
      orElse: () => MonthlyBudget(categoryName: categoryName),
    );

    monthlyBudget.setBudget(month, budget);

    // If the budget was newly created, add it to the list
    if (!_monthlyBudgets.contains(monthlyBudget)) {
      _monthlyBudgets.add(monthlyBudget);
    }

    notifyListeners(); // Notify listeners about the changes

    await _dbHelper.setBudget(categoryName, month, budget);
    ActivityLogger().updated(ActivityEntity.budget, categoryName,
        amount: budget);
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
    notifyListeners();
    await _dbHelper.setTotalBudget(month, amount);
    ActivityLogger()
        .updated(ActivityEntity.budget, 'Total budget', amount: amount);
  }

  // Copy current month's budget to next month
  Future<void> copyBudgetToNextMonth(String currentMonth) async {
    await _dbHelper.copyBudgetToNextMonth(currentMonth);

    final currentParts = currentMonth.split('-');
    final currentDate = currentParts.length == 2
        ? DateTime(
            int.parse(currentParts[0]),
            int.parse(currentParts[1]),
            1,
          )
        : DateTime(DateTime.now().year, int.parse(currentMonth), 1);
    final nextMonth = BudgetPeriod.keyFor(BudgetPeriod.nextMonth(currentDate));

    // Load the next month's data to update the UI
    await loadMonthlyData(nextMonth);

    notifyListeners();
  }
}
