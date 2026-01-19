import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/debt_provider.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';
import '../screens/debt_list_screen.dart';

class DebtSummaryWidget extends StatelessWidget {
  const DebtSummaryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DebtProvider>(
      builder: (context, debtProvider, child) {
        final totalLiabilities = debtProvider.totalLiabilities;
        final totalReceivables = debtProvider.totalReceivables;
        final netPosition = debtProvider.netPosition;
        final activeCount = debtProvider.activeDebtCount;
        final overdueCount = debtProvider.overdueDebtCount;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DebtListScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.spacing20),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Debt Tracker',
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (activeCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: overdueCount > 0
                              ? AppColors.negative.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$activeCount active',
                          style: AppTextStyles.caption.copyWith(
                            color: overdueCount > 0
                                ? AppColors.negative
                                : AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spacing20),

                // Balance Summary
                Row(
                  children: [
                    // Money I Owe
                    Expanded(
                      child: _buildBalanceItem(
                        context,
                        'Money I Owe',
                        totalLiabilities,
                        Icons.arrow_upward,
                        totalLiabilities > 0
                            ? AppColors.negative
                            : context.textSecondary,
                      ),
                    ),
                    Container(
                      height: 60,
                      width: 1,
                      color: context.textSecondary.withValues(alpha: 0.2),
                    ),
                    // Owed to Me
                    Expanded(
                      child: _buildBalanceItem(
                        context,
                        'Owed to Me',
                        totalReceivables,
                        Icons.arrow_downward,
                        totalReceivables > 0
                            ? AppColors.positive
                            : context.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spacing16),

                // Net Position
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: netPosition >= 0
                        ? AppColors.positive.withValues(alpha: 0.1)
                        : AppColors.negative.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            netPosition >= 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            size: 18,
                            color: netPosition >= 0
                                ? AppColors.positive
                                : AppColors.negative,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Net Position',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        UtilityFunction.addCommaWithSign(netPosition.abs()),
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: netPosition >= 0
                              ? AppColors.positive
                              : AppColors.negative,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Overdue Warning
                if (overdueCount > 0) ...[
                  const SizedBox(height: AppDimensions.spacing12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$overdueCount ${overdueCount == 1 ? 'debt is' : 'debts are'} overdue',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                ],

                // Empty State
                if (activeCount == 0 &&
                    totalLiabilities == 0 &&
                    totalReceivables == 0) ...[
                  const SizedBox(height: AppDimensions.spacing8),
                  Center(
                    child: Text(
                      'No active debts • Tap to add',
                      style: AppTextStyles.caption.copyWith(
                        color: context.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceItem(
    BuildContext context,
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: context.textSecondary,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            UtilityFunction.addCommaWithSign(amount),
            style: AppTextStyles.amount.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
