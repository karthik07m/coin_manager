import 'dart:math' as math;

import '../models/transaction.dart';

/// A single piece of spending advice, ordered by how much it matters.
class SpendingSuggestion {
  /// Stable identifier for the rule that produced this, so tests assert on
  /// the reasoning rather than on wording.
  final String kind;

  /// Lower sorts first. Money already lost beats money at risk, which beats
  /// general habit advice.
  final int priority;

  final String text;

  const SpendingSuggestion({
    required this.kind,
    required this.priority,
    required this.text,
  });
}

/// Turns a month of spending into concrete, checkable advice.
///
/// Deliberately grounded in the user's own budgets and last month's figures
/// rather than generic thrift tips: "cut back on coffee" is noise, whereas
/// "Groceries is 18% over its budget with 12 days left" is something they set
/// themselves and can act on.
///
/// Pure and plugin-free so every rule can be tested.
class SpendingAdvisor {
  const SpendingAdvisor._();

  /// Spending must be at least this far ahead of the month's elapsed share
  /// before pace is worth mentioning — budgets are lumpy and a small lead
  /// early in the month is normal.
  static const double _paceTolerance = 1.15;

  /// A category has to grow by this much month over month to be a "spike"
  /// rather than ordinary variation.
  static const double _spikeRatio = 1.4;

  static List<SpendingSuggestion> suggest({
    required List<Transaction> monthExpenses,
    required List<Transaction> previousMonthExpenses,
    required Map<int, String> categoryNames,
    required Map<String, double> categoryBudgets,
    required double Function(Transaction) amountOf,
    required String Function(double) money,
    required int daysElapsed,
    required int daysInMonth,
    /// Categories that are fixed commitments — rent, loans, insurance.
    /// Advice about "setting a budget" for these is noise.
    Set<int> fixedCategoryIds = const {},
    int limit = 4,
  }) {
    final suggestions = <SpendingSuggestion>[];

    final spentByCategory = _totalsByCategory(monthExpenses, amountOf);
    final previousByCategory =
        _totalsByCategory(previousMonthExpenses, amountOf);
    final totalSpent =
        spentByCategory.values.fold<double>(0, (sum, v) => sum + v);

    final elapsedShare = daysInMonth <= 0
        ? 0.0
        : (daysElapsed.clamp(0, daysInMonth)) / daysInMonth;
    final daysLeft = math.max(0, daysInMonth - daysElapsed);

    for (final entry in spentByCategory.entries) {
      final name = categoryNames[entry.key];
      if (name == null) continue;
      final spent = entry.value;
      final budget = categoryBudgets[name] ?? 0;

      if (budget > 0 && spent > budget) {
        final over = spent - budget;
        suggestions.add(SpendingSuggestion(
          kind: 'over_budget',
          priority: 0,
          text: '$name is ${money(over)} over its ${money(budget)} budget '
              '(${_percent(spent / budget)} used). '
              '${daysLeft > 0 ? 'There are $daysLeft days left in the month.' : ''}'
                  .trim(),
        ));
        continue;
      }

      // Ahead of pace: still inside the budget, but on course to break it.
      if (budget > 0 && elapsedShare > 0 && daysLeft > 0) {
        final used = spent / budget;
        if (used > elapsedShare * _paceTolerance) {
          final projected = spent / elapsedShare;
          if (projected > budget) {
            suggestions.add(SpendingSuggestion(
              kind: 'over_pace',
              priority: 1,
              text: '$name is running ahead of pace — ${money(spent)} of '
                  '${money(budget)} with $daysLeft days to go. At this rate '
                  'it lands near ${money(projected)}. About '
                  '${money((budget - spent) / daysLeft)} a day keeps it inside.',
            ));
          }
        }
      }
    }

    // Categories that grew sharply against last month.
    for (final entry in spentByCategory.entries) {
      final name = categoryNames[entry.key];
      if (name == null) continue;
      final previous = previousByCategory[entry.key] ?? 0;
      if (previous <= 0) continue;

      final spent = entry.value;
      if (spent < previous * _spikeRatio) continue;
      // Ignore rounding-level categories where a big ratio means little.
      if (totalSpent > 0 && spent < totalSpent * 0.05) continue;

      suggestions.add(SpendingSuggestion(
        kind: 'category_spike',
        priority: 2,
        text: '$name is up ${_percent(spent / previous - 1)} on last month '
            '(${money(spent)} vs ${money(previous)}). Worth a look if that '
            'was not deliberate.',
      ));
    }

    // Meaningful spending in a category with no budget. Only the largest
    // such category is worth raising: listing every one produces near
    // identical advice repeated down the page.
    final unbudgeted = spentByCategory.entries
        .where((entry) {
          final name = categoryNames[entry.key];
          if (name == null) return false;
          if ((categoryBudgets[name] ?? 0) > 0) return false;
          // A mortgage or rent has no budget because it is a fixed
          // obligation, not an oversight. Telling someone to budget their
          // house payment is not advice.
          if (fixedCategoryIds.contains(entry.key)) return false;
          return totalSpent > 0 && entry.value / totalSpent >= 0.2;
        })
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (unbudgeted.isNotEmpty) {
      final top = unbudgeted.first;
      suggestions.add(SpendingSuggestion(
        kind: 'unbudgeted_category',
        priority: 3,
        text: '${categoryNames[top.key]} took '
            '${_percent(top.value / totalSpent)} of your spending '
            '(${money(top.value)}) and has no budget. Setting one makes it '
            'visible before it grows.',
      ));
    }

    suggestions.sort((a, b) => a.priority.compareTo(b.priority));
    return suggestions.take(limit).toList();
  }

  static Map<int, double> _totalsByCategory(
    List<Transaction> expenses,
    double Function(Transaction) amountOf,
  ) {
    final totals = <int, double>{};
    for (final t in expenses) {
      if (!t.isExpense || t.isTransfer) continue;
      totals[t.categoryId] = (totals[t.categoryId] ?? 0) + amountOf(t);
    }
    return totals;
  }

  static String _percent(double fraction) =>
      '${(fraction * 100).round()}%';
}
