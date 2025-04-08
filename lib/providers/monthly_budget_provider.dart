import 'package:flutter/material.dart';
import '../models/monthly_budget.dart';

class MonthlyBudgetProvider with ChangeNotifier {
  final List<MonthlyBudget> _monthlyBudgets = []; // List to store monthly budgets

  List<MonthlyBudget> get monthlyBudgets => _monthlyBudgets;

  // Method to set budget for a specific category and month
  void setBudget(String categoryName, String month, double budget) {
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
  }

  // Method to get budget for a specific category and month
  double getBudget(String categoryName, String month) {
    MonthlyBudget? monthlyBudget = _monthlyBudgets.firstWhere(
      (budget) => budget.categoryName == categoryName,
      orElse: () => MonthlyBudget(categoryName: categoryName),
    );

    return monthlyBudget.getBudget(month);
  }
}
