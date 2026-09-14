import 'package:coin_manager/utilities/functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'calendar_expense_screen.dart';
import '../widgets/animated_number.dart';
import '../widgets/tappable.dart';

/// Hero tint: a deeper wash of the accent than the page, so the card is the
/// focal surface without going white or fully saturated.
Color _cardColor(BuildContext context) => Color.alphaBlend(
    context.appAccent.withValues(alpha: context.isDark ? 0.22 : 0.2),
    context.appBackground);

/// Inner tiles lift off the card instead of punching white holes in it.
Color _tileColor(BuildContext context) => Color.alphaBlend(
    context.isDark
        ? Colors.black.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.5),
    _cardColor(context));

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
    final balance = totalIncome - totalExpenses;
    final isPositive = balance >= 0;
    final currencySymbol = context.watch<SettingsProvider>().currencySymbol;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: Tappable(
        color: _cardColor(context),
        borderRadius: 28,
        pressedScale: 0.985,
        openPage: CalendarExpenseScreen(selectedMonth: selectedMonth),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Total Balance',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: context.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _showMonthPicker(context),
                    style: TextButton.styleFrom(
                      foregroundColor: context.textPrimary,
                      backgroundColor: _tileColor(context),
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.expand_more_rounded, size: 18),
                    label: Text(DateFormat('MMM yyyy').format(selectedMonth)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedMoney(
                  amount: balance,
                  currencySymbol: currencySymbol,
                  style: AppTextStyles.h1.copyWith(
                      fontSize: 40,
                      letterSpacing: -1.4,
                      color: isPositive
                          ? context.textPrimary
                          : AppColors.negative),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 900),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 16, color: context.textSecondary),
                  const SizedBox(width: 6),
                  Text(isPositive ? 'Healthy' : 'Deficit',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: context.textSecondary)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('·  View calendar',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: context.textSecondary))),
                  Icon(Icons.arrow_forward_rounded,
                      size: 16, color: context.textSecondary),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, constraints) {
                final stack = constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20;
                final income = _buildMetricCard(context,
                    label: 'Income',
                    amount: totalIncome,
                    icon: Icons.south_west_rounded,
                    color: AppColors.positive,
                    currencySymbol: currencySymbol);
                final expense = _buildMetricCard(context,
                    label: 'Expenses',
                    amount: totalExpenses,
                    icon: Icons.north_east_rounded,
                    color: AppColors.negative,
                    currencySymbol: currencySymbol);
                if (stack) {
                  return Column(
                      children: [income, const SizedBox(height: 8), expense]);
                }
                return Row(children: [
                  Expanded(child: income),
                  const SizedBox(width: 12),
                  Expanded(child: expense)
                ]);
              }),
              if (previousMonthExpenses > 0) ...[
                const SizedBox(height: 12),
                _buildSpendingComparison(context, currencySymbol),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
    required String currencySymbol,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _tileColor(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
                child: Text(label,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: context.textSecondary))),
          ]),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
                UtilityFunction.addCommaWithSign(amount,
                    currencySymbol: currencySymbol),
                style: AppTextStyles.amount
                    .copyWith(fontSize: 18, color: context.textPrimary)),
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
        color: _tileColor(context),
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
      backgroundColor: context.appSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(AppDimensions.spacing20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Month',
                style: AppTextStyles.h3.copyWith(
                    color: context.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Previous year',
                  onPressed: () => setState(() {
                    _viewingDate =
                        DateTime(_viewingDate.year - 1, _viewingDate.month);
                  }),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${_viewingDate.year}',
                    style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary)),
                IconButton(
                  tooltip: 'Next year',
                  onPressed: () => setState(() {
                    _viewingDate =
                        DateTime(_viewingDate.year + 1, _viewingDate.month);
                  }),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing20),
            // Month Grid
            // Sizes to its 12 months instead of being clipped to a fixed
            // height, which hid Jul-Dec entirely.
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent:
                      32 + MediaQuery.textScalerOf(context).scale(18),
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
                            ? context.appAccent
                            : context.appBackground,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: context.appBorder,
                                width: 1,
                              ),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('MMM').format(month),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
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
