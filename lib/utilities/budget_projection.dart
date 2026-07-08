import '../models/transaction.dart';

/// Month-end spending projection that doesn't naively extrapolate one-time
/// bills. A raw `spent / daysElapsed * daysInMonth` treats a $2,000 rent paid
/// on the 1st as if it recurs daily. Instead, like mainstream finance apps:
///
///   projected = spent so far                      (fixed bills count once)
///             + scheduled recurring bills still due this month
///             + variable daily run-rate × days remaining
///
/// "Variable" spending excludes recurring transactions and unusually large
/// one-time payments (≥ 20% of the monthly budget), which are already fully
/// counted in "spent so far".
class BudgetProjection {
  final double projected;
  final double variableDailyAverage;
  final double upcomingFixed;

  const BudgetProjection({
    required this.projected,
    required this.variableDailyAverage,
    required this.upcomingFixed,
  });

  static BudgetProjection compute({
    required List<Transaction> monthExpensesToDate,
    required List<Transaction> upcomingRecurring,
    required DateTime selectedMonth,
    required double totalBudget,
  }) {
    final now = DateTime.now();
    final firstOfCurrent = DateTime(now.year, now.month, 1);
    final firstOfSelected =
        DateTime(selectedMonth.year, selectedMonth.month, 1);
    final isPastMonth = firstOfSelected.isBefore(firstOfCurrent);
    final isFutureMonth = firstOfSelected.isAfter(firstOfCurrent);
    final daysInMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;

    final totalSpent =
        monthExpensesToDate.fold(0.0, (sum, t) => sum + t.amount);

    if (isPastMonth) {
      return BudgetProjection(
        projected: totalSpent,
        variableDailyAverage: 0,
        upcomingFixed: 0,
      );
    }
    if (isFutureMonth) {
      return const BudgetProjection(
        projected: 0,
        variableDailyAverage: 0,
        upcomingFixed: 0,
      );
    }

    // Today counts as a remaining day (elapsed + remaining == daysInMonth).
    final daysElapsed = (now.day - 1).clamp(1, daysInMonth);
    final daysRemaining = daysInMonth - now.day + 1;

    // Unusually large single payments (rent paid as a plain transaction,
    // an annual insurance bill…) shouldn't drive the daily run-rate.
    final largeOneTimeThreshold =
        totalBudget > 0 ? totalBudget * 0.20 : double.infinity;

    double variableSpent = 0;
    for (final t in monthExpensesToDate) {
      if (t.isRecurring) continue;
      if (t.amount >= largeOneTimeThreshold) continue;
      variableSpent += t.amount;
    }
    final variableDailyAverage = variableSpent / daysElapsed;

    // Recurring bills scheduled between tomorrow and month end.
    final endOfMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);
    double upcomingFixed = 0;
    for (final t in upcomingRecurring) {
      if (!t.isExpense) continue;
      if (t.date.isAfter(endOfMonth)) continue;
      upcomingFixed += t.amount;
    }

    return BudgetProjection(
      projected:
          totalSpent + upcomingFixed + variableDailyAverage * daysRemaining,
      variableDailyAverage: variableDailyAverage,
      upcomingFixed: upcomingFixed,
    );
  }
}
