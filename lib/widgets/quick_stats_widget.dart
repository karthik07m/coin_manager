import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../utilities/constants.dart';

class QuickStatsWidget extends StatelessWidget {
  const QuickStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionProvider, MonthlyBudgetProvider>(
      builder: (context, transactionProvider, budgetProvider, child) {
        final now = DateTime.now();
        final currentMonth = now.month.toString();

        final totalBudget = budgetProvider.getTotalBudget(currentMonth);
        final totalExpenses = transactionProvider.totalExpenses;
        final budgetRemaining = totalBudget - totalExpenses;
        final budgetUsedPercent =
            totalBudget > 0 ? (totalExpenses / totalBudget * 100) : 0;

        // Calculate days remaining in month
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
        final daysRemaining = lastDayOfMonth.day - now.day + 1;
        final daysInMonth = lastDayOfMonth.day;
        final daysElapsed = daysInMonth - daysRemaining;

        // Calculate average daily spending
        final avgDailySpending =
            daysElapsed > 0 ? totalExpenses / daysElapsed : 0;
        final projectedMonthlySpending = avgDailySpending * daysInMonth;

        return Container(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QUICK STATS',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.spacing12),

              // Budget Status
              if (totalBudget > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Budget Used',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${budgetUsedPercent.toStringAsFixed(0)}%',
                          style: AppTextStyles.h3.copyWith(
                            color: budgetUsedPercent >= 100
                                ? AppColors.negative
                                : budgetUsedPercent >= 80
                                    ? AppColors.warning
                                    : AppColors.positive,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Remaining',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${budgetRemaining.toStringAsFixed(2)}',
                          style: AppTextStyles.h3.copyWith(
                            color: budgetRemaining < 0
                                ? AppColors.negative
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacing12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (budgetUsedPercent / 100).clamp(0.0, 1.0),
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      budgetUsedPercent >= 100
                          ? AppColors.negative
                          : budgetUsedPercent >= 80
                              ? AppColors.warning
                              : AppColors.positive,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing16),
              ],

              // Daily Average & Projection
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Avg/Day',
                      '\$${avgDailySpending.toStringAsFixed(2)}',
                      Icons.calendar_today,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: _buildStatItem(
                      'Projected',
                      '\$${projectedMonthlySpending.toStringAsFixed(0)}',
                      Icons.trending_up,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
