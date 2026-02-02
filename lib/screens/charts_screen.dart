import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/charts/categories_pie_chart.dart';
import '../widgets/charts/accounts_pie_chart.dart';
import '../providers/account_provider.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import 'package:intl/intl.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _isInitialized = false;
  int _selectedChart = 0; // 0 for Expenses, 1 for Accounts

  @override
  void initState() {
    super.initState();
    // Load data when screen is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData(context, _selectedMonth);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when returning to this screen
    if (_isInitialized) {
      _fetchData(context, _selectedMonth);
    }
    _isInitialized = true;
  }

  Future<void> _fetchData(BuildContext context, DateTime month) async {
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);

    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);

    await transactionProvider.loadTransactionsFromDB(
      startDate: startDate,
      endDate: endDate,
    );
    await accountProvider.loadAccounts();
  }

  void _showMonthPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final viewingYear = _selectedMonth.year;
            final months = List.generate(12, (index) {
              return DateTime(viewingYear, index + 1);
            });

            return Dialog(
              backgroundColor: context.appSurface,
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
                            color: context.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedMonth = DateTime(
                                    _selectedMonth.year - 1,
                                    _selectedMonth.month,
                                  );
                                });
                              },
                              icon: Icon(Icons.chevron_left,
                                  color: context.textSecondary),
                            ),
                            Text(
                              '${_selectedMonth.year}',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedMonth = DateTime(
                                    _selectedMonth.year + 1,
                                    _selectedMonth.month,
                                  );
                                });
                              },
                              icon: Icon(Icons.chevron_right,
                                  color: context.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacing20),
                    // Month Grid
                    SizedBox(
                      height: 240, // Fixed height for grid
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.8,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: months.length,
                        itemBuilder: (context, index) {
                          final month = months[index];
                          final isSelected =
                              month.month == _selectedMonth.month &&
                                  month.year == _selectedMonth.year;

                          return InkWell(
                            onTap: () {
                              // Update the parent state and close dialog
                              this.setState(() {
                                _selectedMonth = month;
                              });
                              _fetchData(context, month);
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMedium),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : context.appBackground,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMedium),
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
        elevation: 0,
        title: Text(
          'Charts',
          style: AppTextStyles.h2.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Month selector button
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: () => _showMonthPicker(context),
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text(
                '${DateFormat('MMM yyyy').format(_selectedMonth)} ▼',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: Consumer2<TransactionProvider, AccountProvider>(
        builder: (context, transactionProvider, accountProvider, child) {
          final transactions = transactionProvider.transactions;

          // Calculate total expenses
          double totalExpenses = 0.0;
          for (var transaction in transactions) {
            if (transaction.isExpense) {
              totalExpenses += transaction.amount;
            }
          }

          return RefreshIndicator(
            onRefresh: () => _fetchData(context, _selectedMonth),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              child: Column(
                children: [
                  // Chart Selector
                  Container(
                    width: double.infinity,
                    margin:
                        const EdgeInsets.only(bottom: AppDimensions.spacing20),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.appSurfaceLight,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(
                        color: AppColors.divider.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildTypeSelector(0, 'Expenses'),
                        _buildTypeSelector(1, 'Accounts'),
                      ],
                    ),
                  ),

                  // Chart Card
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spacing20),
                    decoration: BoxDecoration(
                      color: context.appSurfaceLight,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusLarge),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: _selectedChart == 0
                        ? CategoriesPieChart(
                            screenHeight:
                                MediaQuery.of(context).size.height * 0.8,
                            categories: transactionProvider.categories,
                            totalExpenses: totalExpenses,
                            currentMonth: _selectedMonth,
                          )
                        : AccountsPieChart(
                            totalExpenses: totalExpenses,
                            currentMonth: _selectedMonth,
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeSelector(int index, String text) {
    final isSelected = _selectedChart == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedChart = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSelected ? Colors.white : context.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
