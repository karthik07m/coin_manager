import 'package:coin_manager/models/transaction.dart';
import 'package:coin_manager/services/spending_advisor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Advice has to be grounded in the user's own budgets and last month's
/// figures, and it has to stay quiet when there is nothing worth saying.
void main() {
  _fixedCommitments();

  const food = 1;
  const groceries = 2;
  const rent = 3;

  const names = {food: 'Food', groceries: 'Groceries', rent: 'Rent'};

  Transaction expense(double amount, int categoryId, {int day = 5}) {
    return Transaction.createNew(
      id: 'tx$categoryId$amount$day',
      title: 'x',
      amount: amount,
      categoryId: categoryId,
      accountId: 1,
      date: DateTime(2026, 8, day),
      isExpense: true,
    );
  }

  double amountOf(Transaction t) => t.amount;
  String money(double v) => '\$${v.toStringAsFixed(2)}';

  List<SpendingSuggestion> run({
    required List<Transaction> month,
    List<Transaction> previous = const [],
    Map<String, double> budgets = const {},
    int daysElapsed = 15,
    int daysInMonth = 30,
  }) {
    return SpendingAdvisor.suggest(
      monthExpenses: month,
      previousMonthExpenses: previous,
      categoryNames: names,
      categoryBudgets: budgets,
      amountOf: amountOf,
      money: money,
      daysElapsed: daysElapsed,
      daysInMonth: daysInMonth,
    );
  }

  group('over budget', () {
    test('flags a category that has passed its budget', () {
      final out = run(
        month: [expense(450, groceries)],
        budgets: {'Groceries': 400},
      );

      expect(out.first.kind, 'over_budget');
      expect(out.first.text, contains('Groceries'));
      expect(out.first.text, contains('\$50.00'));
      expect(out.first.text, contains('113%'));
    });

    test('over budget outranks every other kind of advice', () {
      final out = run(
        month: [expense(450, groceries), expense(300, food)],
        previous: [expense(50, food)],
        budgets: {'Groceries': 400},
      );

      expect(out.first.kind, 'over_budget');
    });
  });

  group('pace', () {
    test('warns when on course to break a budget', () {
      // Half the month gone, 80% of the budget spent.
      final out = run(
        month: [expense(320, food)],
        budgets: {'Food': 400},
      );

      final pace = out.firstWhere((s) => s.kind == 'over_pace');
      expect(pace.text, contains('Food'));
      expect(pace.text, contains('15 days'));
    });

    test('stays quiet when spending tracks the month', () {
      // Half the month, half the budget — exactly on pace.
      final out = run(
        month: [expense(200, food)],
        budgets: {'Food': 400},
      );

      expect(out.where((s) => s.kind == 'over_pace'), isEmpty);
    });

    test('stays quiet when slightly ahead but not projected to break', () {
      final out = run(
        month: [expense(210, food)],
        budgets: {'Food': 400},
      );

      expect(out.where((s) => s.kind == 'over_pace'), isEmpty);
    });
  });

  group('month-over-month spikes', () {
    test('flags a category that jumped', () {
      final out = run(
        month: [expense(300, food)],
        previous: [expense(100, food)],
      );

      final spike = out.firstWhere((s) => s.kind == 'category_spike');
      expect(spike.text, contains('200%'));
      expect(spike.text, contains('Food'));
    });

    test('ignores a jump in a trivially small category', () {
      // Food tripled but is a rounding error next to rent.
      final out = run(
        month: [expense(30, food), expense(2000, rent)],
        previous: [expense(10, food)],
      );

      expect(out.where((s) => s.kind == 'category_spike'), isEmpty);
    });

    test('says nothing when there is no previous month to compare', () {
      final out = run(month: [expense(300, food)]);
      expect(out.where((s) => s.kind == 'category_spike'), isEmpty);
    });
  });

  group('unbudgeted categories', () {
    test('suggests budgeting a category that dominates spending', () {
      final out = run(
        month: [expense(800, rent), expense(200, food)],
        budgets: {'Food': 300},
      );

      final unbudgeted =
          out.firstWhere((s) => s.kind == 'unbudgeted_category');
      expect(unbudgeted.text, contains('Rent'));
      expect(unbudgeted.text, contains('80%'));
    });

    test('ignores a small unbudgeted category', () {
      final out = run(
        month: [expense(950, rent), expense(50, food)],
        budgets: {'Rent': 1000},
      );

      expect(out.where((s) => s.kind == 'unbudgeted_category'), isEmpty);
    });
  });

  group('restraint', () {
    test('a month inside every budget produces no advice', () {
      final out = run(
        month: [expense(100, food), expense(150, groceries)],
        previous: [expense(110, food), expense(140, groceries)],
        budgets: {'Food': 400, 'Groceries': 400},
      );

      expect(out, isEmpty);
    });

    test('no spending at all produces no advice', () {
      expect(run(month: const []), isEmpty);
    });

    test('transfers never count as spending', () {
      // Transfers are stored with isExpense = true, so an advisor that
      // trusted that flag would report moving savings as overspending.
      final transfer = Transaction.createTransfer(
        id: 't1',
        title: 'move',
        amount: 5000,
        fromAccountId: 1,
        toAccountId: 2,
        date: DateTime(2026, 8, 5),
      );

      expect(run(month: [transfer], budgets: {'Rent': 100}), isEmpty);
    });

    test('advice is capped so the answer stays readable', () {
      final out = run(
        month: [
          expense(450, groceries),
          expense(500, food),
          expense(900, rent),
        ],
        previous: [expense(100, food), expense(100, groceries)],
        budgets: {'Groceries': 400, 'Food': 400},
      );

      expect(out.length, lessThanOrEqualTo(4));
    });
  });
}

/// Fixed commitments must not generate "set a budget" advice, and only the
/// largest unbudgeted category is worth raising.
void _fixedCommitments() {
  const houseLoan = 10;
  const houseRent = 11;
  const dining = 12;

  const names = {
    houseLoan: 'House Loan',
    houseRent: 'House Rent',
    dining: 'Dining Out',
  };

  Transaction expense(double amount, int categoryId) => Transaction.createNew(
        id: 'f$categoryId$amount',
        title: 'x',
        amount: amount,
        categoryId: categoryId,
        accountId: 1,
        date: DateTime(2026, 8, 5),
        isExpense: true,
      );

  List<SpendingSuggestion> run({Set<int> fixed = const {}}) {
    return SpendingAdvisor.suggest(
      monthExpenses: [
        expense(2000, houseLoan),
        expense(1928.95, houseRent),
        expense(400, dining),
      ],
      previousMonthExpenses: const [],
      categoryNames: names,
      categoryBudgets: const {},
      amountOf: (t) => t.amount,
      money: (v) => '\$${v.toStringAsFixed(2)}',
      daysElapsed: 20,
      daysInMonth: 31,
      fixedCategoryIds: fixed,
    );
  }

  group('fixed commitments', () {
    test('does not tell the user to budget their mortgage', () {
      final out = run(fixed: {houseLoan, houseRent});
      expect(
        out.where((s) => s.text.contains('House Loan')),
        isEmpty,
        reason: 'a mortgage has no budget because it is fixed, not forgotten',
      );
    });

    test('raises only the largest unbudgeted category, not every one', () {
      // Both House Loan and House Rent qualified before, producing two
      // near-identical tips one after the other.
      final out = run();
      final unbudgeted =
          out.where((s) => s.kind == 'unbudgeted_category').toList();

      expect(unbudgeted.length, 1);
      expect(unbudgeted.single.text, contains('House Loan'));
    });
  });
}
