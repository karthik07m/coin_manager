import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';

/// A card showing expenses for each month of [year] as a bar chart, so users
/// can see the whole year's spending at a glance beneath the monthly view.
/// The [highlightMonth] (1-12) bar is emphasised.
class YearlyExpensesChart extends StatefulWidget {
  final int year;
  final int highlightMonth;
  const YearlyExpensesChart({
    super.key,
    required this.year,
    required this.highlightMonth,
  });

  @override
  State<YearlyExpensesChart> createState() => _YearlyExpensesChartState();
}

class _YearlyExpensesChartState extends State<YearlyExpensesChart> {
  List<double> _totals = List<double>.filled(12, 0.0);
  bool _loading = true;

  static const List<String> _monthLetters = [
    'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D',
  ];
  static const List<String> _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant YearlyExpensesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year) {
      setState(() => _loading = true);
      _load();
    }
  }

  Future<void> _load() async {
    final tp = context.read<TransactionProvider>();
    final totals = await tp.monthlyExpenseTotals(widget.year);
    if (mounted) {
      setState(() {
        _totals = totals;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<SettingsProvider>().currencySymbol;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: context.appSurfaceLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: context.appAccent.withValues(alpha: 0.2)),
      ),
      child: _loading
          ? const SizedBox(
              height: 200, child: Center(child: CircularProgressIndicator()))
          : _content(context, currency),
    );
  }

  Widget _content(BuildContext context, String currency) {
    final yearTotal = _totals.fold(0.0, (a, b) => a + b);
    final maxV = _totals.reduce((a, b) => a > b ? a : b);
    final maxY = maxV <= 0 ? 1.0 : maxV * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YEARLY EXPENSES',
                    style: AppTextStyles.caption.copyWith(
                      color: context.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    )),
                const SizedBox(height: 6),
                Text(
                  UtilityFunction.formatMoney(yearTotal,
                      symbol: currency, showDecimals: true),
                  style: AppTextStyles.h1.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.appAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.year}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.appAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Spending by month',
          style: AppTextStyles.caption.copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: yearTotal <= 0
              ? Center(
                  child: Text('No expenses this year',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: context.textSecondary)),
                )
              : BarChart(
                  BarChartData(
                    maxY: maxY,
                    alignment: BarChartAlignment.spaceAround,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => context.appSurface,
                        getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                          '${_monthAbbr[group.x]}\n',
                          AppTextStyles.caption
                              .copyWith(color: context.textSecondary),
                          children: [
                            TextSpan(
                              text: UtilityFunction.formatMoney(rod.toY,
                                  symbol: currency, showDecimals: true),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 3,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: context.textSecondary.withValues(alpha: 0.08),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (value, meta) {
                            final i = value.round();
                            if (i < 0 || i > 11) return const SizedBox.shrink();
                            final isSel = (i + 1) == widget.highlightMonth;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _monthLetters[i],
                                style: AppTextStyles.caption.copyWith(
                                  color: isSel
                                      ? context.appAccent
                                      : context.textSecondary,
                                  fontWeight: isSel
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (int i = 0; i < 12; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: _totals[i],
                              width: 13,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                              color: (i + 1) == widget.highlightMonth
                                  ? context.appAccent
                                  : context.appAccent.withValues(alpha: 0.30),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
