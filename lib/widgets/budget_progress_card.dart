import 'package:flutter/material.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';

class BudgetProgressCard extends StatelessWidget {
  final String categoryName;
  final String categoryIcon;
  final double budgetAmount;
  final double spentAmount;
  final int daysRemaining;
  final String currencySymbol;

  const BudgetProgressCard({
    super.key,
    required this.categoryName,
    required this.categoryIcon,
    required this.budgetAmount,
    required this.spentAmount,
    required this.daysRemaining,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final percentSpent = budgetAmount > 0 ? (spentAmount / budgetAmount) : 0.0;
    final remaining = budgetAmount - spentAmount;
    final dailyBudget = daysRemaining > 0 ? remaining / daysRemaining : 0.0;

    // Determine color based on percentage spent
    Color progressColor;
    Color accentColor;
    List<Color> gradientColors;

    if (percentSpent >= 1.0) {
      progressColor = AppColors.negative;
      accentColor = const Color(0xFFFF5252);
      gradientColors = [
        const Color(0xFFFF5252).withValues(alpha: 0.1),
        const Color(0xFFFF1744).withValues(alpha: 0.05),
      ];
    } else if (percentSpent >= 0.8) {
      progressColor = AppColors.warning;
      accentColor = const Color(0xFFFF9800);
      gradientColors = [
        const Color(0xFFFF9800).withValues(alpha: 0.1),
        const Color(0xFFFF6D00).withValues(alpha: 0.05),
      ];
    } else {
      progressColor = AppColors.positive;
      accentColor = const Color(0xFF4CAF50);
      gradientColors = [
        const Color(0xFF4CAF50).withValues(alpha: 0.1),
        const Color(0xFF2E7D32).withValues(alpha: 0.05),
      ];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(
          color: progressColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: progressColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon, Name, Status Badge
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(AppDimensions.spacing12),
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      categoryIcon,
                      width: 24,
                      height: 24,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.category,
                        size: 24,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryName,
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: context.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$daysRemaining days left',
                              style: AppTextStyles.caption.copyWith(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: progressColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${(percentSpent * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: progressColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing16),

              // Amount Display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spent',
                        style: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        UtilityFunction.formatMoney(spentAmount,
                            symbol: currencySymbol),
                        style: AppTextStyles.h2.copyWith(
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Budget',
                        style: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        UtilityFunction.formatMoney(budgetAmount,
                            symbol: currencySymbol),
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing16),

              // Progress Bar with Animation
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: context.appBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(
                        begin: 0,
                        end: percentSpent.clamp(0.0, 1.0),
                      ),
                      builder: (context, value, _) => Container(
                        height: 12,
                        width: MediaQuery.of(context).size.width * value,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              progressColor,
                              progressColor.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: progressColor.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing12),

              // Bottom Stats
              Container(
                padding: const EdgeInsets.all(AppDimensions.spacing12),
                decoration: BoxDecoration(
                  color: context.appBackground.withValues(alpha: 0.5),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        context: context,
                        icon: Icons.trending_down,
                        label: remaining >= 0 ? 'Remaining' : 'Over',
                        value: UtilityFunction.formatMoney(remaining.abs(),
                            symbol: currencySymbol),
                        color:
                            remaining >= 0 ? progressColor : AppColors.negative,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: AppColors.divider,
                    ),
                    Expanded(
                      child: _buildStatItem(
                        context: context,
                        icon: Icons.calendar_today,
                        label: 'Daily Budget',
                        value: UtilityFunction.formatMoney(dailyBudget,
                            symbol: currencySymbol),
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: context.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
