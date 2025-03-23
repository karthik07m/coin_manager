class MonthlyBudget {
  String categoryName;
  Map<String, double> budgets; // Store budgets for each month

  MonthlyBudget({required this.categoryName, Map<String, double>? budgets})
      : budgets = budgets ?? {};

  // Method to set budget for a specific month
  void setBudget(String month, double budget) {
    budgets[month] = budget;
  }

  // Method to get budget for a specific month
  double getBudget(String month) {
    return budgets[month] ?? 0.0;
  }
}
