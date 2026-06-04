import 'package:flutter/material.dart';
import '../models/monthly_budget.dart';
import '../db/monthly_budget_db_helper.dart';

class MonthlyBudgetProvider with ChangeNotifier {
  final List<MonthlyBudget> _monthlyBudgets =
      []; // List to store monthly budgets
  final MonthlyBudgetDBHelper _dbHelper = MonthlyBudgetDBHelper();

  List<MonthlyBudget> get monthlyBudgets => _monthlyBudgets;

  final Map<String, double> _totalBudgets = {};

  double getTotalBudget(String month) => _totalBudgets[month] ?? 0.0;

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
  }

  // Copy current month's budget to next month
  Future<void> copyBudgetToNextMonth(String currentMonth) async {
    await _dbHelper.copyBudgetToNextMonth(currentMonth);

    // Calculate next month and load its data
    final currentMonthInt = int.parse(currentMonth);
    final nextMonthInt = currentMonthInt == 12 ? 1 : currentMonthInt + 1;
    final nextMonth = nextMonthInt.toString();

    // Load the next month's data to update the UI
    await loadMonthlyData(nextMonth);

    notifyListeners();
  }
}
