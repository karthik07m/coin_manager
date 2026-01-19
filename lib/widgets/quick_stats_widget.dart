import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';

class QuickStatsWidget extends StatelessWidget {
  final Function(int)? onTabSelected;

  const QuickStatsWidget({super.key, this.onTabSelected});

  Color _getStatusColor(double percent) {
    if (percent < 50) return AppColors.positive;
    if (percent < 80) return AppColors.warning;
    return AppColors.negative;
  }

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
            totalBudget > 0 ? (totalExpenses / totalBudget * 100) : 0.0;

        // Calculate days remaining in month
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
        final daysRemaining = lastDayOfMonth.day - now.day + 1;
        final daysInMonth = lastDayOfMonth.day;
        final daysElapsed = daysInMonth - daysRemaining;

        // Calculate average daily spending and safe daily budget
        final avgDailySpending =
            daysElapsed > 0 ? totalExpenses / daysElapsed : 0.0;
        final safeDailyBudget = daysRemaining > 0 && budgetRemaining > 0
            ? budgetRemaining / daysRemaining
            : 0.0;

        // Determine status
        Color statusColor = _getStatusColor(budgetUsedPercent);
        String statusText;

        if (budgetUsedPercent < 50) {
          statusText = 'On Track';
        } else if (budgetUsedPercent < 80) {
          statusText = 'Watch It';
        } else if (budgetUsedPercent < 100) {
          statusText = 'Near Limit';
        } else {
          statusText = 'Over Budget';
        }

        return GestureDetector(
          onTap: () {
            // Navigate to Budget tab (index 3)
            onTabSelected?.call(3);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'BUDGET TRACKER',
                        style: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.touch_app,
                        size: 12,
                        color: context.textSecondary,
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

              const SizedBox(height: 16),

              // Progress Bar with Budget Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: UtilityFunction.formatMoney(
                              budgetRemaining.abs()),
                          style: AppTextStyles.h3.copyWith(
                            color: budgetRemaining >= 0
                                ? AppColors.primary
                                : AppColors.negative,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: budgetRemaining >= 0 ? ' left' : ' over',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'of ${UtilityFunction.formatMoney(totalBudget)} budget',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (budgetUsedPercent / 100).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),

              const SizedBox(height: 16),

              // Insights Row
              Row(
                children: [
                  Expanded(
                    child: _buildInsightCard(
                      context,
                      icon: Icons.calendar_today,
                      title: '$daysRemaining',
                      subtitle: 'days left',
                      color: AppColors.accentBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInsightCard(
                      context,
                      icon: Icons.savings,
                      title: UtilityFunction.formatMoney(safeDailyBudget),
                      subtitle: 'safe/day',
                      color: AppColors.positive,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInsightCard(
                      context,
                      icon: Icons.trending_up,
                      title: UtilityFunction.formatMoney(avgDailySpending),
                      subtitle: 'avg/day',
                      color: AppColors.accentPurple,
                    ),
                  ),
                ],
              ),

              // Tap hint
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap for details',
                  style: AppTextStyles.caption.copyWith(
                    color: context.textSecondary.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInsightCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
