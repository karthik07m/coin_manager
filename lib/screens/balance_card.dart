import 'package:coin_manager/utilities/functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'calendar_expense_screen.dart';

class BalanceCard extends StatelessWidget {
  final double screenWidth;
  final double totalIncome;
  final double totalExpenses;
  final double previousMonthExpenses;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const BalanceCard({
    super.key,
    required this.screenWidth,
    required this.totalIncome,
    required this.totalExpenses,
    required this.previousMonthExpenses,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  void _showMonthPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return _MonthPickerDialog(
              initialDate: selectedMonth,
              onMonthSelected: (date) {
                onMonthChanged(date);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double balance = totalIncome - totalExpenses;
    bool isPositive = balance >= 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol =
        Provider.of<SettingsProvider>(context).currencySymbol;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CalendarExpenseScreen(
              selectedMonth: selectedMonth,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.accentBlue.withValues(alpha: 0.1),
                    AppColors.surfaceLight,
                  ]
                : [
                    const Color(0xFFFAFBFC), // Warmer very light gray
                    const Color(0xFFF8F9FA), // Soft warm gray
                    const Color(0xFFFEFEFE), // Off-white
                  ],
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          border: Border.all(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.2)
                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: isDark ? 20 : 10,
              offset: const Offset(0, 4),
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
                        color: context.appSurfaceLight,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSmall),
                        border: Border.all(color: context.appBorder),
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
                          UtilityFunction.addCommaWithSign(balance,
                              currencySymbol: currencySymbol),
                          style: AppTextStyles.h1.copyWith(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: isPositive
                                ? context.textPrimary
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
                      context,
                      label: 'Income',
                      amount: totalIncome,
                      icon: Icons.arrow_upward_rounded,
                      color: AppColors.positive,
                      isIncome: true,
                      currencySymbol: currencySymbol,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      label: 'Expenses',
                      amount: totalExpenses,
                      icon: Icons.arrow_downward_rounded,
                      color: AppColors.negative,
                      isIncome: false,
                      currencySymbol: currencySymbol,
                    ),
                  ),
                ],
              ),

              // Spending Comparison (only show if we have previous month data)
              if (previousMonthExpenses > 0) ...[
                const SizedBox(height: AppDimensions.spacing12),
                _buildSpendingComparison(context, currencySymbol),
              ],
            ],
          ),
        ), // Padding
      ), // Container
    ); // GestureDetector
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
    required bool isIncome,
    required String currencySymbol,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: context.appSurface,
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
                  color: context.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            UtilityFunction.addCommaWithSign(amount,
                currencySymbol: currencySymbol),
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

  Widget _buildSpendingComparison(BuildContext context, String currencySymbol) {
    // Calculate change
    final change = totalExpenses - previousMonthExpenses;
    final percentChange = previousMonthExpenses > 0
        ? (change / previousMonthExpenses * 100)
        : 0.0;

    final isDecrease = change < 0;
    final noChange = change == 0;

    // Color based on change (green = decreased spending, red = increased)
    final Color changeColor = noChange
        ? context.textSecondary
        : isDecrease
            ? AppColors.positive // Green for decreased spending
            : AppColors.negative; // Red for increased spending

    final IconData changeIcon = noChange
        ? Icons.trending_flat
        : isDecrease
            ? Icons.trending_down
            : Icons.trending_up;

    final String changeText = noChange
        ? 'Same as last month'
        : isDecrease
            ? 'Down from last month'
            : 'Up from last month';

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: changeColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: changeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              changeIcon,
              size: 16,
              color: changeColor,
            ),
          ),
          const SizedBox(width: 12),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs Last Month',
                  style: AppTextStyles.caption.copyWith(
                    color: context.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  changeText,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: changeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Percentage and amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!noChange)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDecrease ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 12,
                      color: changeColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${percentChange.abs().toStringAsFixed(1)}%',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 2),
              Text(
                UtilityFunction.addCommaWithSign(
                  change.abs(),
                  currencySymbol: currencySymbol,
                ),
                style: AppTextStyles.caption.copyWith(
                  color: context.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Extracting to a separate widget to cleaner state management for year navigation
class _MonthPickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onMonthSelected;

  const _MonthPickerDialog({
    required this.initialDate,
    required this.onMonthSelected,
  });

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late DateTime _viewingDate;

  @override
  void initState() {
    super.initState();
    _viewingDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final months = List.generate(12, (index) {
      return DateTime(_viewingDate.year, index + 1);
    });

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(AppDimensions.spacing20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Year Navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Month',
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _viewingDate = DateTime(
                            _viewingDate.year - 1,
                            _viewingDate.month,
                          );
                        });
                      },
                      icon: const Icon(Icons.chevron_left,
                          color: AppColors.textSecondary),
                    ),
                    Text(
                      '${_viewingDate.year}',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _viewingDate = DateTime(
                            _viewingDate.year + 1,
                            _viewingDate.month,
                          );
                        });
                      },
                      icon: const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing20),
            // Month Grid
            SizedBox(
              height: 240,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: months.length,
                itemBuilder: (context, index) {
                  final month = months[index];
                  final isSelected = month.month == widget.initialDate.month &&
                      month.year == widget.initialDate.year;

                  return InkWell(
                    onTap: () => widget.onMonthSelected(month),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : context.appBackground,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: AppColors.divider,
                                width: 1,
                              ),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('MMM').format(month),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isSelected
                                ? context.textPrimary
                                : context.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
  }
}
