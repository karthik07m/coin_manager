import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';
import '../utilities/budget_period.dart';
import '../utilities/budget_projection.dart';

/// Monthly budget summary card: one hero number (remaining), one progress
/// bar with a "today" pace marker, and a flat row of the three stats that
/// actually matter. Modeled on mainstream personal-finance apps.
class QuickStatsWidget extends StatelessWidget {
  final Function(int)? onTabSelected;
  final DateTime selectedMonth;

  const QuickStatsWidget({
    super.key,
    this.onTabSelected,
    required this.selectedMonth,
  });

  Color _statusColor(double budgetUsedPercent, double paceDelta) {
    if (budgetUsedPercent >= 100 || paceDelta > 15) return AppColors.negative;
    if (budgetUsedPercent >= 80 || paceDelta > 6) return AppColors.warning;
    return AppColors.positive;
  }

  String _statusText(double budgetUsedPercent, double paceDelta) {
    if (budgetUsedPercent >= 100) return 'Over budget';
    if (paceDelta > 15) return 'Spending fast';
    if (budgetUsedPercent >= 80 || paceDelta > 6) return 'Watch it';
    return 'On track';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<TransactionProvider, MonthlyBudgetProvider,
        SettingsProvider>(
      builder:
          (context, transactionProvider, budgetProvider, settingsProvider, _) {
        final currentMonth = BudgetPeriod.keyFor(selectedMonth);
        final startDate = BudgetPeriod.startOfMonth(selectedMonth);
        final endDate = BudgetPeriod.endOfMonth(selectedMonth);
        final currencySymbol = settingsProvider.currencySymbol;

        final totalBudget = budgetProvider.getTotalBudget(currentMonth);
        final monthExpenses = transactionProvider.transactions
            .where((transaction) =>
                transaction.isExpense &&
                !transaction.date.isBefore(startDate) &&
                !transaction.date.isAfter(endDate))
            .toList();
        final totalExpenses =
            monthExpenses.fold(0.0, (sum, transaction) => sum + transaction.amount);
        final budgetRemaining = totalBudget - totalExpenses;
        final budgetUsedPercent =
            totalBudget > 0 ? (totalExpenses / totalBudget * 100) : 0.0;

        final now = DateTime.now();
        final lastDayOfMonth =
            DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
        final isCurrentMonth =
            selectedMonth.year == now.year && selectedMonth.month == now.month;
        final isPastMonth =
            selectedMonth.isBefore(DateTime(now.year, now.month, 1));

        final daysRemaining = isCurrentMonth
            ? (lastDayOfMonth.day - now.day + 1)
            : isPastMonth
                ? 0
                : lastDayOfMonth.day;
        final daysInMonth = lastDayOfMonth.day;
        final daysElapsed = isCurrentMonth
            ? (daysInMonth - daysRemaining)
            : isPastMonth
                ? daysInMonth
                : 0;
        final elapsedForPace = daysElapsed <= 0 ? 1 : daysElapsed;
        final calendarProgress =
            (elapsedForPace / daysInMonth * 100).clamp(0.0, 100.0);

        final avgDailySpending =
            daysElapsed > 0 ? totalExpenses / daysElapsed : totalExpenses;
        final safeDailyBudget = daysRemaining > 0 && budgetRemaining > 0
            ? budgetRemaining / daysRemaining
            : 0.0;
        // Fixed bills count once; only variable spending extrapolates.
        final projectedSpend = BudgetProjection.compute(
          monthExpensesToDate: monthExpenses,
          upcomingRecurring: transactionProvider.allUpcomingTransactions,
          selectedMonth: selectedMonth,
          totalBudget: totalBudget,
        ).projected;
        final paceDelta =
            totalBudget > 0 ? budgetUsedPercent - calendarProgress : 0.0;

        final statusColor = _statusColor(budgetUsedPercent, paceDelta);
        final statusText = _statusText(budgetUsedPercent, paceDelta);
        final monthName = DateFormat('MMMM').format(selectedMonth);

        String money(double v) =>
            UtilityFunction.formatMoney(v, symbol: currencySymbol);

        return GestureDetector(
          onTap: () {
            onTabSelected?.call(2);
          },
          behavior: HitTestBehavior.opaque,
          child: totalBudget <= 0
              ? _buildNoBudgetState(context, monthName)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MONTHLY BUDGET',
                          style: AppTextStyles.caption.copyWith(
                            color: context.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: AppTextStyles.caption.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Hero: remaining amount
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: money(budgetRemaining.abs()),
                            style: AppTextStyles.h1.copyWith(
                              fontSize: 30,
                              color: budgetRemaining >= 0
                                  ? context.textPrimary
                                  : AppColors.negative,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: budgetRemaining >= 0 ? '  left' : '  over',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCurrentMonth
                          ? 'of ${money(totalBudget)} · $daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} to go'
                          : 'of ${money(totalBudget)} budget',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // One bar. Fill = spent. Tick = where "today" sits.
                    _buildPaceBar(
                      context,
                      spentFraction: (budgetUsedPercent / 100).clamp(0.0, 1.0),
                      todayFraction:
                          (calendarProgress / 100).clamp(0.0, 1.0),
                      showTodayMarker: isCurrentMonth,
                      statusColor: statusColor,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Spent ${money(totalExpenses)} · ${budgetUsedPercent.toStringAsFixed(0)}%',
                          style: AppTextStyles.caption.copyWith(
                            color: context.textSecondary,
                            fontSize: 11,
                            letterSpacing: 0,
                          ),
                        ),
                        if (isCurrentMonth)
                          Text(
                            'Today · ${calendarProgress.toStringAsFixed(0)}%',
                            style: AppTextStyles.caption.copyWith(
                              color: context.textSecondary
                                  .withValues(alpha: 0.7),
                              fontSize: 11,
                              letterSpacing: 0,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Flat stat row — no rainbow tiles.
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: context.appSurface.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.divider.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildStat(
                            context,
                            value: money(safeDailyBudget),
                            label: 'Daily budget',
                          ),
                          _statDivider(context),
                          _buildStat(
                            context,
                            value: money(avgDailySpending),
                            label: 'Avg spent/day',
                          ),
                          _statDivider(context),
                          _buildStat(
                            context,
                            value: money(projectedSpend),
                            label: projectedSpend > totalBudget
                                ? 'Projected · over'
                                : 'Projected',
                            valueColor: projectedSpend > totalBudget
                                ? AppColors.negative
                                : null,
                          ),
                        ],
                      ),
                    ),
                    if (isCurrentMonth) ...[
                      const SizedBox(height: 12),
                      _buildInsightFooter(
                        context,
                        monthExpenses: monthExpenses,
                        projectedSpend: projectedSpend,
                        totalBudget: totalBudget,
                        currencySymbol: currencySymbol,
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildNoBudgetState(BuildContext context, String monthName) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.appAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            size: 22,
            color: context.appAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No budget set for $monthName',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Set one to track spending pace',
                style: AppTextStyles.caption.copyWith(
                  color: context.textSecondary,
                  fontSize: 11,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: context.textSecondary,
        ),
      ],
    );
  }

  /// Single progress bar: colored fill for spending, subtle vertical tick
  /// marking where "today" falls in the month, so pace is read at a glance.
  Widget _buildPaceBar(
    BuildContext context, {
    required double spentFraction,
    required double todayFraction,
    required bool showTodayMarker,
    required Color statusColor,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 14,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Track
              Positioned.fill(
                top: 1,
                bottom: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.divider.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // Fill
              Positioned(
                left: 0,
                top: 1,
                bottom: 1,
                width: width * spentFraction,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // "Today" tick
              if (showTodayMarker)
                Positioned(
                  left: (width * todayFraction - 1.25)
                      .clamp(0.0, width - 2.5),
                  top: -1,
                  bottom: -1,
                  width: 2.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.textPrimary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// One plain-English line: the month-end verdict plus what's driving
  /// spending (absorbs what the separate Spending Forecast card used to say).
  Widget _buildInsightFooter(
    BuildContext context, {
    required List<Transaction> monthExpenses,
    required double projectedSpend,
    required double totalBudget,
    required String currencySymbol,
  }) {
    final delta = projectedSpend - totalBudget;
    final isOver = delta > 0;

    // Top spending category this month.
    final totalsByCategory = <int, double>{};
    for (final t in monthExpenses) {
      totalsByCategory[t.categoryId] =
          (totalsByCategory[t.categoryId] ?? 0) + t.amount;
    }
    String? topCategoryText;
    if (totalsByCategory.isNotEmpty) {
      final top = totalsByCategory.entries
          .reduce((a, b) => a.value >= b.value ? a : b);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      final name = categoryProvider.categoryMap[top.key]?.name;
      if (name != null) {
        topCategoryText =
            '$name is the top spend (${UtilityFunction.formatMoney(top.value, symbol: currencySymbol)})';
      }
    }

    final verdict = isOver
        ? 'At this pace you may end ${UtilityFunction.formatMoney(delta, symbol: currencySymbol)} over.'
        : 'On pace to finish ${UtilityFunction.formatMoney(delta.abs(), symbol: currencySymbol)} under budget.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isOver ? Icons.trending_up_rounded : Icons.check_circle_outline,
          size: 15,
          color: isOver ? AppColors.warning : AppColors.positive,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            topCategoryText != null ? '$verdict $topCategoryText.' : verdict,
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              fontSize: 11.5,
              letterSpacing: 0,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(
    BuildContext context, {
    required String value,
    required String label,
    Color? valueColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: valueColor ?? context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _statDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.divider.withValues(alpha: 0.5),
    );
  }
}
