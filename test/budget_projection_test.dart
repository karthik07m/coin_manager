import 'package:flutter_test/flutter_test.dart';
import 'package:coin_manager/models/transaction.dart';
import 'package:coin_manager/utilities/budget_projection.dart';

/// Helper to build an expense transaction with only the fields the projection
/// cares about (amount, date, isExpense, isRecurring).
Transaction expense(
  double amount,
  DateTime date, {
  bool recurring = false,
  bool isExpense = true,
}) {
  return Transaction.createNew(
    id: 'x${amount}_${date.millisecondsSinceEpoch}',
    title: 't',
    amount: amount,
    categoryId: 1,
    accountId: 1,
    date: date,
    isExpense: isExpense,
    isRecurring: recurring,
  );
}

void main() {
  // Fixed clock: July 6 2026. July has 31 days.
  // Convention: today counts as a REMAINING day, so
  //   daysElapsed  = now.day - 1 = 5
  //   daysRemaining = 31 - 6 + 1 = 26
  final now = DateTime(2026, 7, 6);
  final july = DateTime(2026, 7, 1);

  group('BudgetProjection — current month', () {
    test('elapsed/remaining convention: one 100 expense on July 2', () {
      final result = BudgetProjection.compute(
        monthExpensesToDate: [expense(100, DateTime(2026, 7, 2))],
        upcomingRecurring: const [],
        selectedMonth: july,
        totalBudget: 3100,
        now: now,
      );
      // 100 + 0 + (100/5)*26 = 620
      expect(result.projected, closeTo(620.0, 0.0001));
      expect(result.variableDailyAverage, closeTo(20.0, 0.0001));
    });

    test('recurring expense is excluded from the daily run-rate', () {
      final result = BudgetProjection.compute(
        monthExpensesToDate: [
          expense(2000, july, recurring: true),
          expense(100, DateTime(2026, 7, 2)),
        ],
        upcomingRecurring: const [],
        selectedMonth: july,
        totalBudget: 4800,
        now: now,
      );
      // spent 2100 + 0 + (100/5)*26 = 2620  (NOT 2100/5*31)
      expect(result.projected, closeTo(2620.0, 0.0001));
    });

    test('large one-time payment (>= 20% budget) excluded from run-rate', () {
      // Threshold = 4800 * 0.20 = 960; 2000 >= 960 so it is excluded from
      // the run-rate but still fully counted in "spent".
      final result = BudgetProjection.compute(
        monthExpensesToDate: [
          expense(2000, july), // non-recurring rent
          expense(100, DateTime(2026, 7, 2)),
        ],
        upcomingRecurring: const [],
        selectedMonth: july,
        totalBudget: 4800,
        now: now,
      );
      expect(result.projected, closeTo(2620.0, 0.0001));
    });

    test('zero budget disables the large-one-time filter', () {
      // Threshold is infinity, so the 2000 DOES enter the run-rate.
      final result = BudgetProjection.compute(
        monthExpensesToDate: [
          expense(2000, july),
          expense(100, DateTime(2026, 7, 2)),
        ],
        upcomingRecurring: const [],
        selectedMonth: july,
        totalBudget: 0,
        now: now,
      );
      // 2100 + 0 + (2100/5)*26
      expect(result.projected, closeTo(2100 + (2100 / 5) * 26, 0.0001));
    });

    test('upcoming recurring bills added once; income and next-month ignored', () {
      final result = BudgetProjection.compute(
        monthExpensesToDate: [expense(100, DateTime(2026, 7, 2))],
        upcomingRecurring: [
          expense(327, DateTime(2026, 7, 15)), // this month → counted
          expense(500, DateTime(2026, 8, 3)), // next month → ignored
          expense(999, DateTime(2026, 7, 20), isExpense: false), // income → ignored
        ],
        selectedMonth: july,
        totalBudget: 4800,
        now: now,
      );
      // 100 + 327 + (100/5)*26 = 947
      expect(result.upcomingFixed, closeTo(327.0, 0.0001));
      expect(result.projected, closeTo(947.0, 0.0001));
    });

    test('day 1: daysElapsed clamps to 1 (no divide by zero)', () {
      final result = BudgetProjection.compute(
        monthExpensesToDate: [expense(50, july)],
        upcomingRecurring: const [],
        selectedMonth: july,
        totalBudget: 3100,
        now: DateTime(2026, 7, 1),
      );
      // elapsed clamps to 1, remaining = 31; run-rate = 50/1 = 50
      expect(result.variableDailyAverage, closeTo(50.0, 0.0001));
      expect(result.projected, closeTo(50 + 50 * 31, 0.0001));
    });
  });

  group('BudgetProjection — other months', () {
    test('past month projects to actual spend only', () {
      final result = BudgetProjection.compute(
        monthExpensesToDate: [
          expense(100, DateTime(2026, 6, 2)),
          expense(200, DateTime(2026, 6, 20)),
        ],
        upcomingRecurring: const [],
        selectedMonth: DateTime(2026, 6, 15),
        totalBudget: 4800,
        now: now,
      );
      expect(result.projected, closeTo(300.0, 0.0001));
      expect(result.variableDailyAverage, 0);
      expect(result.upcomingFixed, 0);
    });

    test('future month projects to zero', () {
      final result = BudgetProjection.compute(
        monthExpensesToDate: const [],
        upcomingRecurring: const [],
        selectedMonth: DateTime(2026, 8, 1),
        totalBudget: 4800,
        now: now,
      );
      expect(result.projected, 0);
    });
  });
}
