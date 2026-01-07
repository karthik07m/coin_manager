import 'package:coin_manager/utilities/functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utilities/constants.dart';

class BalanceCard extends StatelessWidget {
  final double screenWidth;
  final double totalIncome;
  final double totalExpenses;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const BalanceCard({
    super.key,
    required this.screenWidth,
    required this.totalIncome,
    required this.totalExpenses,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  void _showMonthPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Month',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing16),
                SizedBox(
                  height: 300,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final date = DateTime(DateTime.now().year, index + 1);
                      final isSelected = date.month == selectedMonth.month;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          onMonthChanged(DateTime(date.year, date.month));
                        },
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSmall),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSmall),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.divider,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              DateFormat('MMM').format(date),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double balance = totalIncome - totalExpenses;
    bool isPositive = balance >= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.accentBlue.withValues(alpha: 0.1),
            AppColors.surfaceLight,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with month selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Balance',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('MMMM yyyy').format(selectedMonth),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Month selector button
                InkWell(
                  onTap: () => _showMonthPicker(context),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSmall),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('MMM').format(selectedMonth),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimensions.spacing20),

            // Balance amount with trend indicator
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        UtilityFunction.addCommaWithSign(balance),
                        style: AppTextStyles.h1.copyWith(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: isPositive
                              ? AppColors.textPrimary
                              : AppColors.negative,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Trend indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? AppColors.positive.withValues(alpha: 0.15)
                              : AppColors.negative.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              size: 14,
                              color: isPositive
                                  ? AppColors.positive
                                  : AppColors.negative,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPositive ? 'Healthy' : 'Deficit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isPositive
                                    ? AppColors.positive
                                    : AppColors.negative,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimensions.spacing20),

            // Income and Expenses cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    label: 'Income',
                    amount: totalIncome,
                    icon: Icons.arrow_upward_rounded,
                    color: AppColors.positive,
                    isIncome: true,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: _buildMetricCard(
                    label: 'Expenses',
                    amount: totalExpenses,
                    icon: Icons.arrow_downward_rounded,
                    color: AppColors.negative,
                    isIncome: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
    required bool isIncome,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
