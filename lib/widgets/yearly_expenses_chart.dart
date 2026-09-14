import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';
import '../utilities/responsive.dart';
import '../utilities/financial_year.dart';

/// Interactive yearly expenses card: animated per-month bars, a dashed
/// average line, and tap-to-inspect. Tapping a bar selects the month and
/// shows its total, share of the year, and delta vs the monthly average;
/// [onViewMonth] lets the parent jump the whole Charts screen to that month.
class YearlyExpensesChart extends StatefulWidget {
  final int year;
  final int highlightMonth;
  final int startMonth;
  final ValueChanged<DateTime>? onViewMonth;
  const YearlyExpensesChart({
    super.key,
    required this.year,
    required this.highlightMonth,
    this.startMonth = 1,
    this.onViewMonth,
  });

  @override
  State<YearlyExpensesChart> createState() => _YearlyExpensesChartState();
}

class _YearlyExpensesChartState extends State<YearlyExpensesChart> {
  List<double> _totals = List<double>.filled(12, 0.0);
  bool _loading = true;
  bool _loadFailed = false;
  int _loadGeneration = 0;
  int? _selectedBar; // 0-11; null → follow the screen's selected month

  FinancialYear get _period => FinancialYear.containing(
      DateTime(widget.year, widget.highlightMonth), startMonth: widget.startMonth);
  int get _highlightIndex => _period.indexOf(DateTime(widget.year, widget.highlightMonth));

  static const List<String> _monthLetters = [
    'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D',
  ];
  static const List<String> _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Currency/rate changes and transaction mutations invalidate the totals.
    context.watch<SettingsProvider>();
    context.watch<TransactionProvider>();
    _load();
  }

  @override
  void didUpdateWidget(covariant YearlyExpensesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year ||
        oldWidget.startMonth != widget.startMonth ||
        FinancialYear.containing(DateTime(oldWidget.year, oldWidget.highlightMonth),
            startMonth: oldWidget.startMonth).start != _period.start) {
      setState(() {
        _loading = true;
        _selectedBar = null;
      });
      _load();
    } else if (oldWidget.highlightMonth != widget.highlightMonth) {
      // Screen month changed (e.g. via View button) — follow it again.
      setState(() => _selectedBar = null);
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    _loading = true;
    _loadFailed = false;
    final tp = context.read<TransactionProvider>();
    final period = _period;
    try {
      final totals = await tp.monthlyExpenseTotals(period.startYear,
          startMonth: period.startMonth);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _totals = totals;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadFailed = true;
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
          : _loadFailed
              ? TextButton(onPressed: () => setState(() { _load(); }),
                  child: const Text('Could not load yearly expenses. Retry'))
              : _content(context, currency),
    );
  }

  Widget _content(BuildContext context, String currency) {
    final yearTotal = _totals.fold(0.0, (a, b) => a + b);
    final maxV = _totals.reduce((a, b) => a > b ? a : b);
    final maxY = maxV <= 0 ? 1.0 : maxV * 1.2;

    // Average over months that actually have spending.
    final activeMonths = _totals.where((v) => v > 0).length;
    final avg = activeMonths > 0 ? yearTotal / activeMonths : 0.0;

    final selIdx = _selectedBar ?? _highlightIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.startMonth == 1 ? 'Yearly expenses' : 'Financial year expenses',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: context.textSecondary,
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
                _period.label,
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
          'Tap a bar to inspect a month',
          style: AppTextStyles.caption.copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: context.chartHeight(fraction: 0.22, min: 150, max: 250),
          child: yearTotal <= 0
              ? Center(
                  child: Text('No expenses this year',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: context.textSecondary)),
                )
              // Bars grow in on load / year change.
              : TweenAnimationBuilder<double>(
                  key: ValueKey('year-anim-${_period.start}'),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, anim, _) => BarChart(
                    BarChartData(
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(
                        handleBuiltInTouches: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => context.appSurface,
                          tooltipBorder: BorderSide(
                            color: context.appAccent.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              UtilityFunction.formatMoney(
                                _totals[groupIndex],
                                symbol: currency,
                                showDecimals: false,
                              ),
                              AppTextStyles.bodySmall.copyWith(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                        touchCallback: (event, response) {
                          if (event is! FlTapUpEvent) return;
                          final idx = response?.spot?.touchedBarGroupIndex;
                          if (idx == null) return;
                          HapticFeedback.selectionClick();
                          setState(() => _selectedBar = idx);
                        },
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 3,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color:
                              context.textSecondary.withValues(alpha: 0.08),
                          strokeWidth: 1,
                        ),
                      ),
                      // Dashed average-month line.
                      extraLinesData: avg > 0
                          ? ExtraLinesData(horizontalLines: [
                              HorizontalLine(
                                y: avg,
                                color: AppColors.warning
                                    .withValues(alpha: 0.85),
                                strokeWidth: 1.4,
                                dashArray: [6, 5],
                                label: HorizontalLineLabel(
                                  show: true,
                                  alignment: Alignment.topRight,
                                  padding:
                                      const EdgeInsets.only(bottom: 3),
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.warning,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  labelResolver: (_) => 'Avg',
                                ),
                              ),
                            ])
                          : const ExtraLinesData(),
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
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final i = value.round();
                              if (i < 0 || i > 11) {
                                  return const SizedBox.shrink();
                              }
                              final isSel = i == selIdx;
                              final isNow =
                                  i == _highlightIndex;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _monthLetters[_period.monthAt(i).month - 1],
                                  style: AppTextStyles.caption.copyWith(
                                    color: isSel
                                        ? context.appAccent
                                        : (isNow
                                            ? context.textPrimary
                                            : context.textSecondary),
                                    fontWeight: isSel || isNow
                                        ? FontWeight.bold
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
                                toY: _totals[i] * anim,
                                width: 16,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: i == selIdx
                                      ? [
                                          context.appAccent,
                                          context.appAccent
                                              .withValues(alpha: 0.7),
                                        ]
                                      : [
                                          context.textSecondary
                                              .withValues(alpha: 0.18),
                                          context.textSecondary
                                              .withValues(alpha: 0.12),
                                        ],
                                ),
                                // Subtle full-height track so empty months
                                // remain tappable and the grid reads well.
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxY,
                                  color: context.textSecondary
                                      .withValues(alpha: 0.04),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
        ),
        if (yearTotal > 0) ...[
          const SizedBox(height: 16),
          _monthDetail(context, currency, selIdx, yearTotal, avg),
        ],
      ],
    );
  }

  /// Detail strip for the selected bar: total, share of year, delta vs the
  /// average month, and a jump-to-month action.
  Widget _monthDetail(BuildContext context, String currency, int selIdx,
      double yearTotal, double avg) {
    final value = _totals[selIdx];
    final pctOfYear = yearTotal > 0 ? value / yearTotal * 100 : 0.0;
    final vsAvg = avg > 0 ? (value - avg) / avg * 100 : 0.0;
    final aboveAvg = vsAvg >= 0;
    // Spending above the average month is bad news → red; below → green.
    final avgColor = aboveAvg ? AppColors.negative : AppColors.positive;
    final maxV = _totals.reduce((a, b) => a > b ? a : b);
    final isPeak = value > 0 && value >= maxV;
    final isCurrent = selIdx == _highlightIndex;
    final month = _period.monthAt(selIdx);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.appAccent.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 6,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: context.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_monthAbbr[month.month - 1]} ${month.year}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    if (isPeak) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.trending_up,
                              size: 10,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Peak month',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  UtilityFunction.formatMoney(value,
                      symbol: currency, showDecimals: true),
                  style: AppTextStyles.h2.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chip(
                      context,
                      '${pctOfYear.toStringAsFixed(pctOfYear < 10 ? 1 : 0)}% of year',
                      context.appAccent,
                      Icons.pie_chart_outline,
                    ),
                    if (avg > 0 && value > 0)
                      _chip(
                        context,
                        '${vsAvg.abs().toStringAsFixed(0)}% ${aboveAvg ? 'above' : 'below'} average',
                        avgColor,
                        aboveAvg ? Icons.trending_up : Icons.trending_down,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (!isCurrent && widget.onViewMonth != null)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onViewMonth!(month);
              },
              style: TextButton.styleFrom(
                foregroundColor: context.appAccent,
                backgroundColor: context.appAccent.withValues(alpha: 0.08),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View',
                      style: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
