import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../widgets/budget_overview_widget.dart';
import '../widgets/quick_stats_widget.dart';
import '../utilities/constants.dart';
import '../utilities/responsive.dart';
import '../utilities/theme_helper.dart';
import '../utilities/budget_period.dart';
import 'package:intl/intl.dart';

class MonthlyBudgetScreen extends StatefulWidget {
  const MonthlyBudgetScreen({super.key});

  @override
  State<MonthlyBudgetScreen> createState() => _MonthlyBudgetScreenState();
}

class _MonthlyBudgetScreenState extends State<MonthlyBudgetScreen> {
  DateTime _selectedMonth = DateTime.now();
  Future<void>? _loadFuture;
  bool _didStartInitialLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didStartInitialLoad) return;

    _didStartInitialLoad = true;
    _loadFuture = _fetchData(context, _selectedMonth);
  }

  Future<void> _fetchData(BuildContext context, DateTime month) async {
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final budgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);

    final startDate = BudgetPeriod.startOfMonth(month);
    final endDate = BudgetPeriod.endOfMonth(month);
    final monthKey = BudgetPeriod.keyFor(month);

    await Future.wait([
      transactionProvider.loadTransactionsFromDB(
        startDate: startDate,
        endDate: endDate,
      ),
      budgetProvider.loadMonthlyData(monthKey),
    ]);
  }

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = DateTime(month.year, month.month);
      _loadFuture = _fetchData(context, _selectedMonth);
    });
  }

  void _showMonthPicker(BuildContext context) {
    var viewingYear = _selectedMonth.year;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final months = List.generate(
              12,
              (index) => DateTime(viewingYear, index + 1),
            );

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Month',
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  viewingYear--;
                                });
                              },
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text(
                              '$viewingYear',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  viewingYear++;
                                });
                              },
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacing16),
                    SizedBox(
                      height: 240,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 160,
                          childAspectRatio: 1.8,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: months.length,
                        itemBuilder: (context, index) {
                          final date = months[index];
                          final isSelected = date.year == _selectedMonth.year &&
                              date.month == _selectedMonth.month;

                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _selectMonth(DateTime(date.year, date.month));
                            },
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSmall),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.appAccent
                                    : context.appSurfaceLight,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusSmall),
                                border: Border.all(
                                  color: isSelected
                                      ? context.appAccent
                                      : AppColors.divider,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  DateFormat('MMM').format(date),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : context.textPrimary,
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        title: const Text('Monthly Budget'),
        elevation: 0,
        actions: [
          // Compact month selector
          InkWell(
            onTap: () => _showMonthPicker(context),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.appSurfaceLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: context.appAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMM yyyy').format(_selectedMonth),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.appAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    color: context.appAccent,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _loadFuture,
        builder: (context, snapshot) {
          return RefreshIndicator(
            onRefresh: () {
              final future = _fetchData(context, _selectedMonth);
              setState(() {
                _loadFuture = future;
              });
              return future;
            },
            color: context.appAccent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              child: context.constrainedContent(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Stats
                    QuickStatsWidget(
                      selectedMonth: _selectedMonth,
                    ),

                    const SizedBox(height: AppDimensions.spacing24),

                    // Budget Overview with all categories
                    BudgetOverviewWidget(
                      selectedMonth: _selectedMonth,
                      onMonthChanged: _selectMonth,
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
