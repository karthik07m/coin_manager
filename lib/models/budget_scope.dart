/// What a month's budget is measured against.
///
/// [allExpenses] is the "spending cap" model: every expense counts, so the
/// budget answers "how much am I allowed to spend in total".
///
/// [budgetedCategories] is the envelope model used by mainstream budgeting
/// apps: only spending in categories you actually budgeted counts, so a
/// $1,000 grocery-and-food budget isn't blown by rent. Spending outside those
/// categories is still reported, separately, as unbudgeted.
enum BudgetScope {
  allExpenses,
  budgetedCategories;

  static const String _allStorage = 'all';
  static const String _categoriesStorage = 'categories';

  String get storageValue =>
      this == BudgetScope.budgetedCategories ? _categoriesStorage : _allStorage;

  /// Anything unrecognised (including null, from rows written before scopes
  /// existed) keeps the original whole-spending behaviour.
  static BudgetScope fromStorage(Object? value) =>
      value == _categoriesStorage
          ? BudgetScope.budgetedCategories
          : BudgetScope.allExpenses;

  String get label => this == BudgetScope.budgetedCategories
      ? 'Budgeted categories'
      : 'All expenses';

  String get description => this == BudgetScope.budgetedCategories
      ? 'Only spending in categories you budgeted counts. Everything else is tracked as unbudgeted.'
      : 'Every expense this month counts toward the budget.';
}
