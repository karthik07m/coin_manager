import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/debt_provider.dart';
import '../screens/balance_card.dart';
import '../widgets/recent_transactions_widget.dart';
import '../widgets/quick_stats_widget.dart';
import '../widgets/budget_expenses_chart_widget.dart';
import '../widgets/debt_summary_widget.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

class HomePage extends StatefulWidget {
  final Function(int)? onTabSelected;

  const HomePage({super.key, this.onTabSelected});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Load categories, transactions, and debts on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      categoryProvider.fetchAllCategories();
      final debtProvider = Provider.of<DebtProvider>(context, listen: false);
      debtProvider.loadDebtsFromDB();
      _fetchData(context, _selectedMonth);
    });
  }

  Future<void> _fetchData(BuildContext context, DateTime month) async {
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);

    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);

    await transactionProvider.loadTransactionsFromDB(
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: Consumer2<TransactionProvider, SettingsProvider>(
        builder: (context, transactionProvider, settingsProvider, child) {
          final transactions = transactionProvider.transactions;

          // Calculate totals
          double totalIncome = 0.0;
          double totalExpenses = 0.0;

          for (var transaction in transactions) {
            if (transaction.isExpense) {
              totalExpenses += transaction.amount;
            } else {
              totalIncome += transaction.amount;
            }
          }

          return RefreshIndicator(
            onRefresh: () => _fetchData(context, _selectedMonth),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: AppDimensions.spacing16),

                  // Balance Card
                  BalanceCard(
                    screenWidth: MediaQuery.of(context).size.width,
                    totalIncome: totalIncome,
                    totalExpenses: totalExpenses,
                    selectedMonth: _selectedMonth,
                    onMonthChanged: (DateTime newMonth) {
                      setState(() {
                        _selectedMonth = newMonth;
                      });
                      _fetchData(context, newMonth);
                    },
                  ),

                  const SizedBox(height: AppDimensions.spacing20),

                  // Budget Quick Stats
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing16,
                    ),
                    padding: const EdgeInsets.all(AppDimensions.spacing16),
                    decoration: BoxDecoration(
                      color: context.appSurfaceLight,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusLarge),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: QuickStatsWidget(
                      onTabSelected: widget.onTabSelected,
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacing20),

                  // Debt Summary
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing16,
                    ),
                    child: const DebtSummaryWidget(),
                  ),

                  const SizedBox(height: AppDimensions.spacing20),

                  // Budget vs Expenses Chart
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing16,
                    ),
                    padding: const EdgeInsets.all(AppDimensions.spacing16),
                    decoration: BoxDecoration(
                      color: context.appSurfaceLight,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusLarge),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: const BudgetExpensesChartWidget(),
                  ),

                  const SizedBox(height: AppDimensions.spacing20),

                  // Recent Transactions
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing16,
                    ),
                    padding: const EdgeInsets.all(AppDimensions.spacing16),
                    decoration: BoxDecoration(
                      color: context.appSurfaceLight,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusLarge),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: RecentTransactionsWidget(
                      onTabSelected: widget.onTabSelected,
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
