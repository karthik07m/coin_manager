import 'package:flutter/material.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';

/// Compact, scannable per-category budget row (real finance-app style):
/// one header line (name + %), a spent-of-budget / remaining sub-line, a slim
/// progress bar, and a single pace caption. Status color (green / amber / red)
/// carries the "how am I doing" signal instead of a heavy tinted card.
class BudgetProgressCard extends StatelessWidget {
  final String categoryName;
  final String categoryIcon;
  final double budgetAmount;
  final double spentAmount;
  final int daysRemaining;
  final int daysElapsed;
  final int periodDays;
  final String currencySymbol;

  const BudgetProgressCard({
    super.key,
    required this.categoryName,
    required this.categoryIcon,
    required this.budgetAmount,
    required this.spentAmount,
    required this.daysRemaining,
    required this.daysElapsed,
    required this.periodDays,
    required this.currencySymbol,
  });

  String _money(double v) =>
      UtilityFunction.formatMoney(v, symbol: currencySymbol);

  @override
  Widget build(BuildContext context) {
    final percentSpent = budgetAmount > 0 ? (spentAmount / budgetAmount) : 0.0;
    final remaining = budgetAmount - spentAmount;
    final isOver = remaining < 0;

    // Pace: how spending compares to a straight-line burn of the budget.
    final elapsedBudget = budgetAmount > 0 && periodDays > 0
        ? budgetAmount * (daysElapsed / periodDays)
        : 0.0;
    final paceDelta = spentAmount - elapsedBudget;
    final isOverPace = paceDelta > 0.01;

    // Status color drives the whole row: green ok, amber ≥80%, red over.
    final Color statusColor;
    if (percentSpent >= 1.0) {
      statusColor = AppColors.negative;
    } else if (percentSpent >= 0.8) {
      statusColor = AppColors.warning;
    } else {
      statusColor = AppColors.positive;
    }

    final pct = (percentSpent * 100).round();
    final needsAttention = percentSpent >= 0.8;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurfaceLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(
          color: needsAttention
              ? statusColor.withValues(alpha: 0.35)
              : AppColors.divider.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Category icon
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Image.asset(
                  categoryIcon,
                  width: 22,
                  height: 22,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.category, size: 22, color: statusColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            categoryName,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$pct%',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_money(spentAmount)} of ${_money(budgetAmount)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOver
                              ? '${_money(remaining.abs())} over'
                              : '${_money(remaining)} left',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isOver
                                ? AppColors.negative
                                : context.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Slim progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(
                begin: 0,
                end: percentSpent.clamp(0.0, 1.0),
              ),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: context.appBackground,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Single pace caption
          Row(
            children: [
              Icon(
                isOverPace
                    ? Icons.trending_up_rounded
                    : Icons.check_circle_outline_rounded,
                size: 13,
                color: isOverPace ? AppColors.warning : AppColors.positive,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  isOverPace
                      ? '${_money(paceDelta.abs())} ahead of pace'
                      : 'On track · ${_money(paceDelta.abs())} under pace',
                  style: AppTextStyles.caption.copyWith(
                    color: context.textSecondary,
                    fontSize: 11.5,
                    letterSpacing: 0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
