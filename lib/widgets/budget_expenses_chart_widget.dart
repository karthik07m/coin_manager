import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/transaction_provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

class BudgetExpensesChartWidget extends StatefulWidget {
  final DateTime selectedMonth;

  const BudgetExpensesChartWidget({
    super.key,
    required this.selectedMonth,
  });

  @override
  State<BudgetExpensesChartWidget> createState() =>
      _BudgetExpensesChartWidgetState();
}

class _BudgetExpensesChartWidgetState extends State<BudgetExpensesChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int? touchedIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<TransactionProvider, MonthlyBudgetProvider,
        SettingsProvider>(
      builder: (context, transactionProvider, budgetProvider, settingsProvider,
          child) {
        final currentMonth = widget.selectedMonth.month.toString();
        final totalBudget = budgetProvider.getTotalBudget(currentMonth);
        final currencySymbol = settingsProvider.currencySymbol;

        // Calculate daily data for the month
        final dailyData = _calculateDailyData(
          transactionProvider,
          widget.selectedMonth,
          totalBudget,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with legend
            // Header with legend or active details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (touchedIndex != null) ...[
                  // Active State: Show Date and Values
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAY ${touchedIndex!.toInt()}',
                        style: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _buildValueItem(
                            'Budget',
                            _getValueAtDay(dailyData['budgetSpots'],
                                touchedIndex!.toDouble()),
                            AppColors.positive,
                            currencySymbol,
                          ),
                          const SizedBox(width: 12),
                          _buildValueItem(
                            'Spent',
                            _getValueAtDay(dailyData['expenseSpots'],
                                touchedIndex!.toDouble()),
                            AppColors.negative,
                            currencySymbol,
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else ...[
                  // Default State: Show Title and Legend
                  Text(
                    'BUDGET VS EXPENSES',
                    style: AppTextStyles.caption.copyWith(
                      color: context.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Row(
                    children: [
                      _buildLegendItem('Budget', AppColors.positive),
                      const SizedBox(width: 12),
                      _buildLegendItem('Expenses', AppColors.negative),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Chart
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return SizedBox(
                  height: 200,
                  child: LineChart(
                    _buildChartData(
                        dailyData, _animation.value, currencySymbol),
                    duration: const Duration(milliseconds: 250),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: context.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double value, String symbol) {
    if (value >= 1000) {
      // Show in thousands with 1 decimal place
      return '$symbol${(value / 1000).toStringAsFixed(1)}k';
    } else if (value >= 100) {
      // Show whole dollars for hundreds
      return '$symbol${value.toStringAsFixed(0)}';
    } else if (value > 0) {
      // Show with 1 decimal for smaller values
      return '$symbol${value.toStringAsFixed(1)}';
    } else {
      // Show $0 for zero
      return '${symbol}0';
    }
  }

  double _getValueAtDay(List<FlSpot> spots, double day) {
    try {
      return spots.firstWhere((spot) => spot.x == day).y;
    } catch (_) {
      return 0.0;
    }
  }

  Widget _buildValueItem(
      String label, double value, Color color, String currencySymbol) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$label: ',
                style: AppTextStyles.caption.copyWith(
                  color: context.textSecondary.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              TextSpan(
                text: _formatCurrency(value, currencySymbol),
                style: AppTextStyles.caption.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _calculateDailyData(
    TransactionProvider transactionProvider,
    DateTime selectedMonth,
    double totalBudget,
  ) {
    final daysInMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final dailyBudget = totalBudget / daysInMonth;

    // Determine how many days to show based on whether we're viewing current month or past month
    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;
    final isPastMonth =
        selectedMonth.isBefore(DateTime(now.year, now.month, 1));

    // For current month, show up to today; for past months, show all days; for future months, show day 1
    final currentDay = isCurrentMonth
        ? now.day
        : isPastMonth
            ? daysInMonth
            : 1;

    List<FlSpot> budgetSpots = [];
    List<FlSpot> expenseSpots = [];

    double cumulativeBudget = 0;
    double cumulativeExpenses = 0;

    // Calculate cumulative data for each day
    for (int day = 1; day <= currentDay; day++) {
      cumulativeBudget += dailyBudget;

      // Calculate expenses for this day
      final dayStart = DateTime(selectedMonth.year, selectedMonth.month, day);
      final dayEnd =
          DateTime(selectedMonth.year, selectedMonth.month, day, 23, 59, 59);

      final dayExpenses = transactionProvider.transactions
          .where((t) =>
              t.isExpense &&
              t.date.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
              t.date.isBefore(dayEnd.add(const Duration(seconds: 1))))
          .fold(0.0, (sum, t) => sum + t.amount);

      cumulativeExpenses += dayExpenses;

      budgetSpots.add(FlSpot(day.toDouble(), cumulativeBudget));
      expenseSpots.add(FlSpot(day.toDouble(), cumulativeExpenses));
    }

    // Add projection for remaining days
    final projectedDays = [currentDay + 7, currentDay + 14, daysInMonth]
        .where((d) => d > currentDay && d <= daysInMonth)
        .toList();

    for (var day in projectedDays) {
      final projectedBudget = dailyBudget * day;
      budgetSpots.add(FlSpot(day.toDouble(), projectedBudget));
    }

    // Calculate maximum Y value from both budget and expenses to prevent clip/overflow
    final maxBudget = budgetSpots.isNotEmpty ? budgetSpots.last.y : 0.0;
    final maxExpense = expenseSpots.isNotEmpty ? expenseSpots.last.y : 0.0;
    var absoluteMax = maxBudget > maxExpense ? maxBudget : maxExpense;

    // Ensure a minimum Y value to prevent flat line bugs when data is 0
    if (absoluteMax <= 0) absoluteMax = 100;

    return {
      'budgetSpots': budgetSpots,
      'expenseSpots': expenseSpots,
      'maxY': (absoluteMax * 1.15)
          .ceilToDouble(), // Add 15% breathing room instead of 10%
      'currentDay': currentDay,
      'daysInMonth': daysInMonth,
    };
  }

  LineChartData _buildChartData(
      Map<String, dynamic> data, double progress, String currencySymbol) {
    final List<FlSpot> budgetSpots = data['budgetSpots'];
    final List<FlSpot> expenseSpots = data['expenseSpots'];
    final double maxY = data['maxY'];
    final int currentDay = data['currentDay'];
    final int daysInMonth = data['daysInMonth'];

    // Animate the spots
    final animatedBudgetSpots =
        budgetSpots.map((spot) => FlSpot(spot.x, spot.y * progress)).toList();
    final animatedExpenseSpots =
        expenseSpots.map((spot) => FlSpot(spot.x, spot.y * progress)).toList();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY > 0 ? maxY / 4 : 100, // Prevent zero interval
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: AppColors.divider.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: [5, 5],
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: 1, // We control visibility manually
            getTitlesWidget: (value, meta) {
              // Ensure we only process whole integers to avoid duplication at boundaries
              if (value != value.toInt().toDouble())
                return const SizedBox.shrink();

              final val = value.toInt();
              // Show: 1st, 7th, 14th, 21st, 28th, and Last Day
              // This provides better spacing than 1, 10, 20
              if (val == 1 ||
                  val == 7 ||
                  val == 14 ||
                  val == 21 ||
                  val == 28 ||
                  val == daysInMonth) {
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    val.toString(),
                    style: AppTextStyles.caption.copyWith(
                      color: context.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            interval: maxY > 0 ? maxY / 4 : 100,
            getTitlesWidget: (value, meta) {
              // Hide negative values to avoid duplicate "0" due to bottom buffer
              if (value < 0) return const SizedBox.shrink();

              return Text(
                _formatCurrency(value, currencySymbol),
                style: AppTextStyles.caption.copyWith(
                  color: context.textSecondary,
                  fontSize: 10,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      clipData: const FlClipData
          .none(), // Allow markers to draw outside the axis range to prevent cutoff
      minX: 0.5, // Buffer at start
      maxX: daysInMonth + 0.5, // Buffer at end
      minY: -maxY *
          0.1, // Increased negative buffer to handle spline overshoot at the bottom
      maxY: maxY,
      lineBarsData: [
        // Budget line
        LineChartBarData(
          spots: animatedBudgetSpots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: AppColors.positive,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              if (index == currentDay - 1) {
                return FlDotCirclePainter(
                  radius: 5,
                  color: AppColors.positive,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              }
              return FlDotCirclePainter(
                radius: 0,
                color: Colors.transparent,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                AppColors.positive.withValues(alpha: 0.3),
                AppColors.positive.withValues(alpha: 0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Expenses line
        LineChartBarData(
          spots: animatedExpenseSpots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: AppColors.negative,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              if (index == expenseSpots.length - 1) {
                return FlDotCirclePainter(
                  radius: 5,
                  color: AppColors.negative,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              }
              return FlDotCirclePainter(
                radius: 0,
                color: Colors.transparent,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                AppColors.negative.withValues(alpha: 0.3),
                AppColors.negative.withValues(alpha: 0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        // bgTouchTooltipInterface removed as it is invalid
        touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
          if (event is FlPanEndEvent || event is FlTapUpEvent) {
            setState(() {
              touchedIndex = null;
            });
          } else if (response != null && response.lineBarSpots != null) {
            final value = response.lineBarSpots!.first.x.toInt();
            if (touchedIndex != value) {
              setState(() {
                touchedIndex = value;
              });
              HapticFeedback.selectionClick();
            }
          }
        },
        getTouchedSpotIndicator:
            (LineChartBarData barData, List<int> spotIndexes) {
          return spotIndexes.map((spotIndex) {
            return TouchedSpotIndicatorData(
              FlLine(
                color: context.textSecondary.withValues(alpha: 0.2),
                strokeWidth: 2,
                dashArray: [5, 5],
              ),
              FlDotData(
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 6,
                    color: barData.color ?? Colors.white,
                    strokeWidth: 3,
                    strokeColor: Theme.of(context).colorScheme.surface,
                  );
                },
              ),
            );
          }).toList();
        },
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            // Return null to hide default tooltips since we show data in header
            return touchedSpots.map((_) => null).toList();
          },
        ),
      ),
    );
  }
}
