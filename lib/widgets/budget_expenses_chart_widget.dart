import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/transaction_provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';
import '../utilities/budget_period.dart';
import '../utilities/budget_projection.dart';
import '../utilities/responsive.dart';

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

/// All derived numbers for the month, computed once per build.
class _ChartData {
  final List<FlSpot> paceSpots; // cumulative pro-rated budget
  final List<FlSpot> expenseSpots; // cumulative spending
  final List<FlSpot> projectionSpots; // dotted continuation to month end
  final double maxY;
  final int currentDay;
  final int daysInMonth;
  final double totalBudget;
  final double spent;
  final double projectedTotal;
  final bool isCurrentMonth;
  final bool isPastMonth;

  _ChartData({
    required this.paceSpots,
    required this.expenseSpots,
    required this.projectionSpots,
    required this.maxY,
    required this.currentDay,
    required this.daysInMonth,
    required this.totalBudget,
    required this.spent,
    required this.projectedTotal,
    required this.isCurrentMonth,
    required this.isPastMonth,
  });

  bool get hasBudget => totalBudget > 0;
  double get remaining => totalBudget - spent;
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
      duration: const Duration(milliseconds: 1200),
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
        final currentMonth = BudgetPeriod.keyFor(widget.selectedMonth);
        final totalBudget = budgetProvider.getTotalBudget(currentMonth);
        final currencySymbol = settingsProvider.currencySymbol;

        final data = _calculateData(
          transactionProvider,
          widget.selectedMonth,
          totalBudget,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(data, currencySymbol),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return SizedBox(
                  height: context.chartHeight(fraction: 0.24, min: 160, max: 260),
                  child: LineChart(
                    _buildChartData(data, _animation.value, currencySymbol),
                    duration: const Duration(milliseconds: 250),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildInsightRow(data, currencySymbol),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Header: title + legend, or the touched day's details
  // ---------------------------------------------------------------------

  Widget _buildHeader(_ChartData data, String currencySymbol) {
    if (touchedIndex == null) {
      return Row(
        children: [
          Text(
            'BUDGET VS SPENDING',
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          // Legend shrinks instead of overflowing on narrow widths.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                children: [
                  if (data.hasBudget) ...[
                    _buildLegendItem('Budget', AppColors.positive,
                        dashed: true),
                    const SizedBox(width: 10),
                  ],
                  _buildLegendItem('Spent', AppColors.negative),
                  if (data.projectionSpots.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    _buildLegendItem('Forecast', context.textSecondary,
                        dashed: true),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    final day = touchedIndex!.clamp(1, data.daysInMonth);
    final date = DateTime(
      widget.selectedMonth.year,
      widget.selectedMonth.month,
      day,
    );
    final isFuture = day > data.currentDay;
    final spentAtDay = isFuture
        ? _projectedAtDay(data, day)
        : _getValueAtDay(data.expenseSpots, day.toDouble());
    final budgetAtDay = data.hasBudget
        ? data.totalBudget / data.daysInMonth * day
        : 0.0;
    final delta = budgetAtDay - spentAtDay;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM d').format(date).toUpperCase(),
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
                  isFuture ? 'Forecast' : 'Spent',
                  spentAtDay,
                  AppColors.negative,
                  currencySymbol,
                ),
                if (data.hasBudget) ...[
                  const SizedBox(width: 12),
                  _buildValueItem(
                    'Budget',
                    budgetAtDay,
                    AppColors.positive,
                    currencySymbol,
                  ),
                ],
              ],
            ),
          ],
        ),
        if (data.hasBudget && !isFuture)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (delta >= 0 ? AppColors.positive : AppColors.negative)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              delta >= 0
                  ? '${_formatCurrency(delta, currencySymbol)} under pace'
                  : '${_formatCurrency(-delta, currencySymbol)} over pace',
              style: AppTextStyles.caption.copyWith(
                color: delta >= 0 ? AppColors.positive : AppColors.negative,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Insight chips: the actionable numbers, no touch required
  // ---------------------------------------------------------------------

  Widget _buildInsightRow(_ChartData data, String currencySymbol) {
    if (!data.hasBudget) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: context.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'No budget set for this month — set one to see pace and forecast.',
              style: AppTextStyles.caption.copyWith(
                color: context.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      );
    }

    final chips = <Widget>[
      _buildInsightChip(
        label: 'Spent',
        value: _formatCurrency(data.spent, currencySymbol),
        color: context.textPrimary,
      ),
      _buildInsightChip(
        label: data.remaining >= 0 ? 'Left' : 'Over by',
        value: _formatCurrency(data.remaining.abs(), currencySymbol),
        color:
            data.remaining >= 0 ? AppColors.positive : AppColors.negative,
      ),
    ];

    if (data.isCurrentMonth && data.spent > 0) {
      final overForecast = data.projectedTotal > data.totalBudget;
      chips.add(_buildInsightChip(
        label: 'Forecast',
        value: _formatCurrency(data.projectedTotal, currencySymbol),
        color: overForecast ? AppColors.warning : AppColors.positive,
        icon: overForecast ? Icons.trending_up : Icons.check_circle_outline,
      ));
    } else if (data.isPastMonth) {
      final under = data.remaining >= 0;
      chips.add(_buildInsightChip(
        label: under ? 'Ended' : 'Ended',
        value: under ? 'Under budget' : 'Over budget',
        color: under ? AppColors.positive : AppColors.negative,
        icon: under ? Icons.check_circle_outline : Icons.error_outline,
      ));
    }

    return Row(
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: chips[i]),
        ],
      ],
    );
  }

  Widget _buildInsightChip({
    required String label,
    required String value,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.appBackground.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              fontSize: 9,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {bool dashed = false}) {
    return Row(
      children: [
        if (dashed)
          Row(
            children: List.generate(
              3,
              (i) => Container(
                width: 4,
                height: 3,
                margin: EdgeInsets.only(right: i == 2 ? 0 : 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          )
        else
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

  // Axis labels follow the selected currency's conventions (lakh/crore for
  // INR, k/M otherwise) instead of always using "k".
  String _formatCurrency(double value, String symbol) {
    return UtilityFunction.formatCompactMoney(value, symbol: symbol);
  }

  double _getValueAtDay(List<FlSpot> spots, double day) {
    try {
      return spots.firstWhere((spot) => spot.x == day).y;
    } catch (_) {
      return 0.0;
    }
  }

  double _projectedAtDay(_ChartData data, int day) {
    if (data.currentDay == 0) return 0;
    return data.spent / data.currentDay * day;
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

  // ---------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------

  _ChartData _calculateData(
    TransactionProvider transactionProvider,
    DateTime selectedMonth,
    double totalBudget,
  ) {
    final daysInMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final dailyBudget = totalBudget / daysInMonth;

    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;
    final isPastMonth =
        selectedMonth.isBefore(DateTime(now.year, now.month, 1));

    final currentDay = isCurrentMonth
        ? now.day
        : isPastMonth
            ? daysInMonth
            : 1;

    List<FlSpot> paceSpots = [];
    List<FlSpot> expenseSpots = [];

    double cumulativeExpenses = 0;

    for (int day = 1; day <= currentDay; day++) {
      final dayStart = DateTime(selectedMonth.year, selectedMonth.month, day);
      final dayEnd =
          DateTime(selectedMonth.year, selectedMonth.month, day, 23, 59, 59);

      final dayExpenses = transactionProvider.transactions
          .where((t) =>
              t.isExpense &&
              t.date.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
              t.date.isBefore(dayEnd.add(const Duration(seconds: 1))))
          .fold(0.0, (sum, t) => sum + transactionProvider.baseAmount(t));

      cumulativeExpenses += dayExpenses;

      paceSpots.add(FlSpot(day.toDouble(), dailyBudget * day));
      expenseSpots.add(FlSpot(day.toDouble(), cumulativeExpenses));
    }

    // Extend the budget pace line to the end of the month.
    if (currentDay < daysInMonth) {
      paceSpots.add(FlSpot(daysInMonth.toDouble(), dailyBudget * daysInMonth));
    }

    // Spending forecast — same engine as the Monthly Budget card: fixed
    // bills count once, only variable spending extrapolates.
    final spent = cumulativeExpenses;
    final monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final observedEnd = DateTime(
        selectedMonth.year, selectedMonth.month, currentDay, 23, 59, 59);
    final monthExpenses = transactionProvider.transactions
        .where((t) =>
            t.isExpense &&
            !t.date.isBefore(monthStart) &&
            !t.date.isAfter(observedEnd))
        .toList();
    final projectedTotal = BudgetProjection.compute(
      monthExpensesToDate: monthExpenses,
      upcomingRecurring: transactionProvider.allUpcomingTransactions,
      selectedMonth: selectedMonth,
      totalBudget: totalBudget,
    ).projected;
    List<FlSpot> projectionSpots = [];
    if (isCurrentMonth && currentDay < daysInMonth && spent > 0) {
      projectionSpots = [
        FlSpot(currentDay.toDouble(), spent),
        FlSpot(daysInMonth.toDouble(), projectedTotal),
      ];
    }

    // Y range must fit the budget cap line and the forecast endpoint.
    var absoluteMax = [
      totalBudget,
      spent,
      projectedTotal,
      if (paceSpots.isNotEmpty) paceSpots.last.y,
    ].reduce((a, b) => a > b ? a : b);
    if (absoluteMax <= 0) absoluteMax = 100;

    return _ChartData(
      paceSpots: totalBudget > 0 ? paceSpots : [],
      expenseSpots: expenseSpots,
      projectionSpots: projectionSpots,
      maxY: (absoluteMax * 1.18).ceilToDouble(),
      currentDay: currentDay,
      daysInMonth: daysInMonth,
      totalBudget: totalBudget,
      spent: spent,
      projectedTotal: projectedTotal,
      isCurrentMonth: isCurrentMonth,
      isPastMonth: isPastMonth,
    );
  }

  // ---------------------------------------------------------------------
  // Chart
  // ---------------------------------------------------------------------

  LineChartData _buildChartData(
      _ChartData data, double progress, String currencySymbol) {
    final animatedPaceSpots = data.paceSpots
        .map((spot) => FlSpot(spot.x, spot.y * progress))
        .toList();
    final animatedExpenseSpots = data.expenseSpots
        .map((spot) => FlSpot(spot.x, spot.y * progress))
        .toList();
    final animatedProjectionSpots = data.projectionSpots
        .map((spot) => FlSpot(spot.x, spot.y * progress))
        .toList();

    final maxY = data.maxY;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY > 0 ? maxY / 4 : 100,
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
            interval: 1,
            getTitlesWidget: (value, meta) {
              if (value != value.toInt().toDouble()) {
                return const SizedBox.shrink();
              }

              final val = value.toInt();
              if (val == 1 ||
                  val == 7 ||
                  val == 14 ||
                  val == 21 ||
                  val == 28 ||
                  val == data.daysInMonth) {
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
      clipData: const FlClipData.none(),
      minX: 0.5,
      maxX: data.daysInMonth + 0.5,
      minY: -maxY * 0.1,
      maxY: maxY,
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          // The budget cap: the single most important reference.
          if (data.hasBudget)
            HorizontalLine(
              y: data.totalBudget * progress,
              color: AppColors.positive.withValues(alpha: 0.55),
              strokeWidth: 1.5,
              dashArray: [6, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 4, bottom: 2),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.positive,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
                labelResolver: (_) =>
                    'Budget ${_formatCurrency(data.totalBudget, currencySymbol)}',
              ),
            ),
        ],
        verticalLines: [
          // Today marker for the current month.
          if (data.isCurrentMonth && data.currentDay < data.daysInMonth)
            VerticalLine(
              x: data.currentDay.toDouble(),
              color: context.textSecondary.withValues(alpha: 0.25),
              strokeWidth: 1,
              dashArray: [3, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(left: 3),
                style: AppTextStyles.caption.copyWith(
                  color: context.textSecondary.withValues(alpha: 0.8),
                  fontSize: 9,
                ),
                labelResolver: (_) => 'Today',
              ),
            ),
        ],
      ),
      lineBarsData: [
        // Budget pace reference line (dashed, subtle)
        if (data.paceSpots.isNotEmpty)
          LineChartBarData(
            spots: animatedPaceSpots,
            isCurved: false,
            color: AppColors.positive.withValues(alpha: 0.8),
            barWidth: 2,
            isStrokeCapRound: true,
            dashArray: [7, 6],
            dotData: const FlDotData(show: false),
          ),
        // Spending forecast (dotted, neutral)
        if (animatedProjectionSpots.isNotEmpty)
          LineChartBarData(
            spots: animatedProjectionSpots,
            isCurved: false,
            color: context.textSecondary.withValues(alpha: 0.7),
            barWidth: 2,
            isStrokeCapRound: true,
            dashArray: [3, 5],
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                if (index == animatedProjectionSpots.length - 1) {
                  return FlDotCirclePainter(
                    radius: 3.5,
                    color: context.textSecondary,
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  );
                }
                return FlDotCirclePainter(
                    radius: 0, color: Colors.transparent);
              },
            ),
          ),
        // Actual spending (the hero line)
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
              if (index == data.expenseSpots.length - 1) {
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
                AppColors.negative.withValues(alpha: 0.28),
                AppColors.negative.withValues(alpha: 0.04),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
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
            // Values are shown in the header instead of a tooltip.
            return touchedSpots.map((_) => null).toList();
          },
        ),
      ),
    );
  }
}
