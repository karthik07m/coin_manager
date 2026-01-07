import 'package:flutter/material.dart';
import '../utilities/constants.dart';

class BudgetProgressCard extends StatelessWidget {
  final String categoryName;
  final String categoryIcon;
  final double budgetAmount;
  final double spentAmount;
  final int daysRemaining;

  const BudgetProgressCard({
    super.key,
    required this.categoryName,
    required this.categoryIcon,
    required this.budgetAmount,
    required this.spentAmount,
    required this.daysRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final percentSpent = budgetAmount > 0 ? (spentAmount / budgetAmount) : 0.0;
    final remaining = budgetAmount - spentAmount;

    // Determine color based on percentage spent
    Color progressColor;
    if (percentSpent >= 1.0) {
      progressColor = AppColors.negative; // Red - over budget
    } else if (percentSpent >= 0.8) {
      progressColor = AppColors.warning; // Orange - warning
    } else {
      progressColor = AppColors.positive; // Green - good
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: progressColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon, Name, Amount
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(AppDimensions.spacing8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Image.asset(
                  categoryIcon,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.category,
                    size: 24,
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
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$daysRemaining days left',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${spentAmount.toStringAsFixed(0)}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                  ),
                  Text(
                    'of \$${budgetAmount.toStringAsFixed(0)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentSpent.clamp(0.0, 1.0),
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),

          // Remaining Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                remaining >= 0 ? 'Remaining' : 'Over budget',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '\$${remaining.abs().toStringAsFixed(2)}',
                style: AppTextStyles.caption.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
