import 'package:coin_manager/models/budget_scope.dart';
import 'package:coin_manager/models/category.dart';
import 'package:coin_manager/models/transaction.dart';
import 'package:coin_manager/utilities/budget_scope_summary.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction expense(double amount, int categoryId) {
  return Transaction.createNew(
    id: 'tx_${categoryId}_$amount',
    title: 'expense',
    amount: amount,
    categoryId: categoryId,
    accountId: 1,
    date: DateTime(2026, 8, 10),
    isExpense: true,
  );
}

Category category(int id, String name) => Category(
      id: id,
      name: name,
      icon: 'assets/categories/bill.png',
      isExpense: true,
    );

const foodId = 1;
const groceriesId = 2;
const rentId = 3;

double identityAmount(Transaction t) => t.amount;

void main() {
  final monthExpenses = [
    expense(300, foodId),
    expense(250, groceriesId),
    expense(2000, rentId),
  ];

  group('BudgetScopeSummary', () {
    test('all-expenses scope counts every expense', () {
      final summary = BudgetScopeSummary.compute(
        monthExpenses: monthExpenses,
        amountOf: identityAmount,
        scope: BudgetScope.allExpenses,
        budgetedCategoryIds: {foodId, groceriesId},
      );

      expect(summary.countedSpent, 2550);
      expect(summary.unbudgetedSpent, 0);
      expect(summary.isCategoryScoped, isFalse);
    });

    test('category scope counts only budgeted categories', () {
      // The point of the feature: a $1,000 food+groceries budget must not be
      // blown by rent, which belongs to no budgeted category.
      final summary = BudgetScopeSummary.compute(
        monthExpenses: monthExpenses,
        amountOf: identityAmount,
        scope: BudgetScope.budgetedCategories,
        budgetedCategoryIds: {foodId, groceriesId},
      );

      expect(summary.countedSpent, 550);
      expect(summary.unbudgetedSpent, 2000);
      expect(summary.totalSpent, 2550);
      expect(summary.isCategoryScoped, isTrue);
      expect(summary.countedExpenses.length, 2);
    });

    test('category scope with nothing budgeted falls back to all expenses', () {
      // Counting nothing would render an empty budget as 0% used.
      final summary = BudgetScopeSummary.compute(
        monthExpenses: monthExpenses,
        amountOf: identityAmount,
        scope: BudgetScope.budgetedCategories,
        budgetedCategoryIds: const {},
      );

      expect(summary.countedSpent, 2550);
      expect(summary.unbudgetedSpent, 0);
      expect(summary.scopeFellBackToAllExpenses, isTrue);
      expect(summary.isCategoryScoped, isFalse);
    });

    test('spending only outside the scope leaves the budget untouched', () {
      final summary = BudgetScopeSummary.compute(
        monthExpenses: [expense(2000, rentId)],
        amountOf: identityAmount,
        scope: BudgetScope.budgetedCategories,
        budgetedCategoryIds: {foodId},
      );

      expect(summary.countedSpent, 0);
      expect(summary.unbudgetedSpent, 2000);
    });

    test('amountOf is used, so converted currencies are respected', () {
      final summary = BudgetScopeSummary.compute(
        monthExpenses: [expense(100, foodId)],
        amountOf: (t) => t.amount * 2, // stand-in for FX conversion
        scope: BudgetScope.budgetedCategories,
        budgetedCategoryIds: {foodId},
      );

      expect(summary.countedSpent, 200);
    });

    test('budgetedCategoryIds picks up only categories with an amount', () {
      final ids = BudgetScopeSummary.budgetedCategoryIds(
        categories: [
          category(foodId, 'Food'),
          category(groceriesId, 'Groceries'),
          category(rentId, 'Rent'),
        ],
        budgetFor: (name) => switch (name) {
          'Food' => 600.0,
          'Groceries' => 400.0,
          _ => 0.0,
        },
      );

      expect(ids, {foodId, groceriesId});
    });
  });

  group('BudgetScope storage', () {
    test('round-trips through storage values', () {
      for (final scope in BudgetScope.values) {
        expect(BudgetScope.fromStorage(scope.storageValue), scope);
      }
    });

    test('rows written before scopes existed read as all-expenses', () {
      expect(BudgetScope.fromStorage(null), BudgetScope.allExpenses);
      expect(BudgetScope.fromStorage('nonsense'), BudgetScope.allExpenses);
    });
  });
}
