import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/account_provider.dart';
import '../screens/balance_card.dart';
import '../widgets/recent_transactions_widget.dart';
import '../widgets/quick_stats_widget.dart';
import '../widgets/budget_expenses_chart_widget.dart';
import '../widgets/debt_summary_widget.dart';
import '../utilities/constants.dart';
import '../widgets/upcoming_payments_widget.dart';
import '../utilities/theme_helper.dart';
import '../widgets/shimmer_loading.dart';

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
    // Load categories, transactions, debts, and accounts on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      categoryProvider.fetchAllCategories();
      final debtProvider = Provider.of<DebtProvider>(context, listen: false);
      debtProvider.loadDebtsFromDB();
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);
      accountProvider.loadAccounts();
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
    await transactionProvider.loadUpcomingTransactions();

    // Load previous month for comparison
    await transactionProvider.loadPreviousMonthExpenses(month);
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
              child: transactionProvider.isTransactionsLoaded
                  ? _buildContent(
                      context,
                      transactionProvider,
                      totalIncome,
                      totalExpenses,
                    )
                  : _buildShimmer(context),
            ),
          );
        },
      ),
    );
  }

  /// Shimmer skeleton while data loads — replaces the blank-to-content flash.
  Widget _buildShimmer(BuildContext context) {
    return ShimmerLoading(
      isLoading: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimensions.spacing16),
            // Balance card skeleton
            ShimmerBox(
              height: 200,
              width: double.infinity,
              borderRadius: AppDimensions.radiusLarge,
            ),
            const SizedBox(height: AppDimensions.spacing20),
            // Quick stats skeleton
            ShimmerBox(
              height: 100,
              width: double.infinity,
              borderRadius: AppDimensions.radiusLarge,
            ),
            const SizedBox(height: AppDimensions.spacing20),
            // Upcoming payments skeleton
            ShimmerBox(
              height: 80,
              width: double.infinity,
              borderRadius: AppDimensions.radiusLarge,
            ),
            const SizedBox(height: AppDimensions.spacing20),
            // Chart skeleton
            ShimmerBox(
              height: 220,
              width: double.infinity,
              borderRadius: AppDimensions.radiusLarge,
            ),
            const SizedBox(height: AppDimensions.spacing20),
            // Recent transactions skeleton
            ...List.generate(4, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  ShimmerCircle(size: 44),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(height: 14, width: double.infinity, borderRadius: 8),
                        const SizedBox(height: 8),
                        ShimmerBox(height: 12, width: 100, borderRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ShimmerBox(height: 14, width: 64, borderRadius: 8),
                ],
              ),
            )),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    TransactionProvider transactionProvider,
    double totalIncome,
    double totalExpenses,
  ) {
    return Column(
      children: [
        const SizedBox(height: AppDimensions.spacing16),

        // Balance Card
        RepaintBoundary(
          child: BalanceCard(
            screenWidth: MediaQuery.of(context).size.width,
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            previousMonthExpenses: transactionProvider.previousMonthExpenses,
            selectedMonth: _selectedMonth,
            onMonthChanged: (DateTime newMonth) {
              setState(() {
                _selectedMonth = newMonth;
              });
              _fetchData(context, newMonth);
            },
          ),
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
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: QuickStatsWidget(
            onTabSelected: widget.onTabSelected,
            selectedMonth: _selectedMonth,
          ),
        ),

        const SizedBox(height: AppDimensions.spacing20),

        // Upcoming Payments
        const Padding(
          padding:
              EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
          child: UpcomingPaymentsWidget(),
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
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: RepaintBoundary(
            child: BudgetExpensesChartWidget(
              selectedMonth: _selectedMonth,
            ),
          ),
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
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
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
    );
  }
}
