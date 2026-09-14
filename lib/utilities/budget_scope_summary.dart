import '../models/budget_scope.dart';
import '../models/category.dart';
import '../models/transaction.dart';

/// Splits a month's spending into what counts against the budget and what
/// doesn't, according to the budget's [BudgetScope].
///
/// Every screen that shows "spent vs budget" runs through this, so the home
/// card, the budget screen and the chart can never disagree about what the
/// denominator covers.
class BudgetScopeSummary {
  /// Expenses that count against the budget. Passed to the projection so
  /// forecasts stay on the same basis as the progress bar.
  final List<Transaction> countedExpenses;

  final double countedSpent;

  /// Spending that falls outside the budget's categories. Always surfaced —
  /// money the budget ignores must never silently vanish from the UI.
  final double unbudgetedSpent;

  final BudgetScope scope;

  /// True when the budget is category-scoped but no category has a budget
  /// yet. Counting nothing would make an empty budget look untouched, so the
  /// whole month is counted and the UI prompts for a category split.
  final bool scopeFellBackToAllExpenses;

  const BudgetScopeSummary({
    required this.countedExpenses,
    required this.countedSpent,
    required this.unbudgetedSpent,
    required this.scope,
    required this.scopeFellBackToAllExpenses,
  });

  bool get isCategoryScoped =>
      scope == BudgetScope.budgetedCategories && !scopeFellBackToAllExpenses;

  double get totalSpent => countedSpent + unbudgetedSpent;

  static BudgetScopeSummary compute({
    required List<Transaction> monthExpenses,
    required double Function(Transaction) amountOf,
    required BudgetScope scope,
    required Set<int> budgetedCategoryIds,
  }) {
    double sum(Iterable<Transaction> items) =>
        items.fold(0.0, (total, t) => total + amountOf(t));

    if (scope == BudgetScope.allExpenses || budgetedCategoryIds.isEmpty) {
      return BudgetScopeSummary(
        countedExpenses: monthExpenses,
        countedSpent: sum(monthExpenses),
        unbudgetedSpent: 0,
        scope: scope,
        scopeFellBackToAllExpenses: scope == BudgetScope.budgetedCategories,
      );
    }

    final counted = <Transaction>[];
    final outside = <Transaction>[];
    for (final t in monthExpenses) {
      if (budgetedCategoryIds.contains(t.categoryId)) {
        counted.add(t);
      } else {
        outside.add(t);
      }
    }

    return BudgetScopeSummary(
      countedExpenses: counted,
      countedSpent: sum(counted),
      unbudgetedSpent: sum(outside),
      scope: scope,
      scopeFellBackToAllExpenses: false,
    );
  }

  /// The categories a category-scoped budget covers: those carrying a budget
  /// amount for the month.
  static Set<int> budgetedCategoryIds({
    required Iterable<Category> categories,
    required double Function(String categoryName) budgetFor,
  }) {
    final ids = <int>{};
    for (final category in categories) {
      final id = category.id;
      if (id != null && budgetFor(category.name) > 0) {
        ids.add(id);
      }
    }
    return ids;
  }
}
