import 'package:flutter/material.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';

/// Compact, scannable per-category budget row (real finance-app style):
/// one header line (name + %), a spent-of-budget / remaining sub-line, a slim
/// progress bar, and a single pace caption. Status color (green / amber / red)
class BudgetProgressCard extends StatelessWidget {
  final String categoryName;
  final String categoryIcon;
  final Color categoryColor;
  final double budgetAmount;
  final double spentAmount;
  final int transactionCount;
  final int daysRemaining;
  final int daysElapsed;
  final int periodDays;
  final String currencySymbol;
  final VoidCallback? onTap;

  const BudgetProgressCard({
    super.key,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.budgetAmount,
    required this.spentAmount,
    required this.transactionCount,
    required this.daysRemaining,
    required this.daysElapsed,
    required this.periodDays,
    required this.currencySymbol,
    this.onTap,
  });

  String _money(double v) =>
      UtilityFunction.formatMoney(v, symbol: currencySymbol);

  @override
  Widget build(BuildContext context) {
    final percentSpent = budgetAmount > 0 ? (spentAmount / budgetAmount) : 0.0;

    // Status color drives the whole row: green ok, amber >=80%, red over.
    final Color statusColor;
    if (percentSpent >= 1.0) {
      statusColor = AppColors.negative;
    } else if (percentSpent >= 0.8) {
      statusColor = AppColors.warning;
    } else {
      statusColor = AppColors.positive;
    }

    final String txText = transactionCount == 1
        ? '1 transaction'
        : '$transactionCount transactions';

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Circular progress ring with icon
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(
                            begin: 0,
                            end: percentSpent.clamp(0.0, 1.0),
                          ),
                          builder: (context, value, _) =>
                              CircularProgressIndicator(
                            value: value,
                            strokeWidth: 3.5,
                            backgroundColor: context.appBackground,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Image.asset(
                        categoryIcon,
                        width: 24,
                        height: 24,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.category, size: 24, color: statusColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing16),

                // Details Column
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Name and Amount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              categoryName,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: context.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Flexible: at large text scales the amounts alone
                          // are wider than the row.
                          Flexible(
                            child: RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: _money(spentAmount),
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: percentSpent >= 1.0
                                          ? AppColors.negative
                                          : context.textPrimary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' / ${_money(budgetAmount)}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: context.textSecondary
                                          .withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Bottom row: Linear progress bar and Transactions count
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 6,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeOutCubic,
                                tween: Tween<double>(
                                  begin: 0,
                                  end: percentSpent.clamp(0.0, 1.0),
                                ),
                                builder: (context, value, _) =>
                                    LinearProgressIndicator(
                                  value: value,
                                  minHeight: 4.5,
                                  backgroundColor: context.appBackground,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      statusColor),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: Text(
                              txText,
                              textAlign: TextAlign.right,
                              style: AppTextStyles.caption.copyWith(
                                color: context.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
