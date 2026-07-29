import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';
import '../utilities/responsive.dart';

/// A card showing net worth over the last few months as an area line chart,
/// with the current value and the change across the period.
class NetWorthTrendChart extends StatefulWidget {
  final int months;
  const NetWorthTrendChart({super.key, this.months = 6});

  @override
  State<NetWorthTrendChart> createState() => _NetWorthTrendChartState();
}

class _NetWorthTrendChartState extends State<NetWorthTrendChart> {
  List<NetWorthPoint> _points = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final ap = context.read<AccountProvider>();
    final base = context.read<SettingsProvider>().currencyCode;
    if (!ap.isLoaded) await ap.loadAccounts();
    await ap.loadRates(base);
    final pts = await ap.netWorthTrend(months: widget.months);
    if (mounted) {
      setState(() {
        _points = pts;
        _loading = false;
      });
    }
  }

  static const List<String> _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<SettingsProvider>().currencySymbol;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: context.appAccent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _loading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : _points.length < 2
              ? _empty(context)
              : _content(context, currency),
    );
  }

  Widget _content(BuildContext context, String currency) {
    final current = _points.last.netWorth;
    final first = _points.first.netWorth;
    final change = current - first;
    final up = change >= 0;
    final changeColor = up ? AppColors.positive : AppColors.negative;

    final values = _points.map((p) => p.netWorth).toList();
    double minV = values.reduce((a, b) => a < b ? a : b);
    double maxV = values.reduce((a, b) => a > b ? a : b);
    if (minV == maxV) {
      minV -= 1;
      maxV += 1;
    }
    final pad = (maxV - minV) * 0.15;
    final minY = minV - pad;
    final maxY = maxV + pad;

    final spots = <FlSpot>[
      for (int i = 0; i < _points.length; i++)
        FlSpot(i.toDouble(), _points[i].netWorth),
    ];
    final lineColor = up ? AppColors.positive : AppColors.negative;

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
                Text('NET WORTH TREND',
                    style: AppTextStyles.caption.copyWith(
                      color: context.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    )),
                const SizedBox(height: 6),
                Text(
                  UtilityFunction.formatMoney(current,
                      symbol: currency, showDecimals: true),
                  style: AppTextStyles.h1.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    color: current >= 0
                        ? context.textPrimary
                        : AppColors.negative,
                  ),
                ),
              ],
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: changeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: changeColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    up
                        ? Icons.trending_up
                        : Icons.trending_down,
                    size: 14,
                    color: changeColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${up ? '+' : ''}${UtilityFunction.formatMoney(change.abs(), symbol: currency, showDecimals: true)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: changeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Over the last ${_points.length} months',
          style: AppTextStyles.caption
              .copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: context.chartHeight(fraction: 0.21, min: 140, max: 240),
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              minX: 0,
              maxX: (_points.length - 1).toDouble(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval:
                    (maxY - minY) > 0 ? (maxY - minY) / 3 : 1,
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
                    interval: 1,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 || i >= _points.length) {
                        return const SizedBox.shrink();
                      }
                      final isLast = i == _points.length - 1;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _monthAbbr[_points[i].month.month - 1],
                          style: AppTextStyles.caption.copyWith(
                            color: isLast ? context.appAccent : context.textSecondary,
                            fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => context.appSurface,
                  tooltipBorder: BorderSide(
                    color: lineColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) => spots.map((s) {
                    final p = _points[s.x.round()];
                    return LineTooltipItem(
                      '${_monthAbbr[p.month.month - 1]} ${p.month.year}\n',
                      AppTextStyles.caption.copyWith(
                        color: context.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: UtilityFunction.formatMoney(p.netWorth,
                              symbol: currency,
                              showDecimals: false),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: lineColor,
                  barWidth: 3.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, pct, bar, i) =>
                        FlDotCirclePainter(
                      radius: i == _points.length - 1 ? 5 : 0,
                      color: lineColor,
                      strokeWidth: 3,
                      strokeColor: context.appSurface,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        lineColor.withValues(alpha: 0.2),
                        lineColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    return SizedBox(
      height: context.chartHeight(fraction: 0.2, min: 130, max: 220),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded,
                size: 44,
                color: context.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text('Not enough history yet',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: context.textSecondary)),
            const SizedBox(height: 4),
            Text('Your net worth trend will appear as months pass',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption
                    .copyWith(color: context.textSecondary)),
          ],
        ),
      ),
    );
  }
}
