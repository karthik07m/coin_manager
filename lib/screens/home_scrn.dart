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
import '../widgets/goal_summary_widget.dart';
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

    // Independent loads — run in parallel instead of serially.
    await Future.wait([
      transactionProvider.loadTransactionsFromDB(
        startDate: startDate,
        endDate: endDate,
      ),
      transactionProvider.loadUpcomingTransactions(),
      // Previous month for comparison
      transactionProvider.loadPreviousMonthExpenses(month),
    ]);
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
            color: Theme.of(context).colorScheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: transactionProvider.isTransactionsLoaded
                  ? _buildContent(
                      context,
                      transactionProvider,
                      settingsProvider,
                      totalIncome,
                      totalExpenses,
                    )
                  : _buildShimmer(context, settingsProvider),
            ),
          );
        },
      ),
    );
  }

  /// Shimmer skeleton while data loads — replaces the blank-to-content flash.
  Widget _buildShimmer(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    return ShimmerLoading(
      isLoading: true,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimensions.spacing16),
            if (settingsProvider.showHomeBalanceCard) ...[
              ShimmerBox(
                height: 200,
                width: double.infinity,
                borderRadius: AppDimensions.radiusLarge,
              ),
              const SizedBox(height: AppDimensions.spacing20),
            ],
            if (settingsProvider.showHomeQuickStats) ...[
              ShimmerBox(
                height: 100,
                width: double.infinity,
                borderRadius: AppDimensions.radiusLarge,
              ),
              const SizedBox(height: AppDimensions.spacing20),
            ],
            if (settingsProvider.showHomeUpcomingPayments) ...[
              ShimmerBox(
                height: 80,
                width: double.infinity,
                borderRadius: AppDimensions.radiusLarge,
              ),
              const SizedBox(height: AppDimensions.spacing20),
            ],
            if (settingsProvider.showHomeDebtSummary) ...[
              ShimmerBox(
                height: 120,
                width: double.infinity,
                borderRadius: AppDimensions.radiusLarge,
              ),
              const SizedBox(height: AppDimensions.spacing20),
            ],
            if (settingsProvider.showHomeGoals) ...[
              ShimmerBox(
                height: 120,
                width: double.infinity,
                borderRadius: AppDimensions.radiusLarge,
              ),
              const SizedBox(height: AppDimensions.spacing20),
            ],
            if (settingsProvider.showHomeBudgetChart) ...[
              ShimmerBox(
                height: 220,
                width: double.infinity,
                borderRadius: AppDimensions.radiusLarge,
              ),
              const SizedBox(height: AppDimensions.spacing20),
            ],
            if (settingsProvider.showHomeRecentTransactions)
              ...List.generate(
                4,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      ShimmerCircle(size: 44),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(
                              height: 14,
                              width: double.infinity,
                              borderRadius: 8,
                            ),
                            const SizedBox(height: 8),
                            ShimmerBox(
                              height: 12,
                              width: 100,
                              borderRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ShimmerBox(height: 14, width: 64, borderRadius: 8),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    TransactionProvider transactionProvider,
    SettingsProvider settingsProvider,
    double totalIncome,
    double totalExpenses,
  ) {
    if (!settingsProvider.hasVisibleHomeWidgets) {
      return _buildAllWidgetsHiddenState(context);
    }
    final accentColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        const SizedBox(height: AppDimensions.spacing16),

        // Balance Card
        if (settingsProvider.showHomeBalanceCard) ...[
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
        ],

        // Budget Quick Stats
        if (settingsProvider.showHomeQuickStats) ...[
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
            ),
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            decoration: BoxDecoration(
              color: context.appSurfaceLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: QuickStatsWidget(
              onTabSelected: widget.onTabSelected,
              selectedMonth: _selectedMonth,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing20),
        ],

        // Upcoming Payments
        if (settingsProvider.showHomeUpcomingPayments) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
            child: UpcomingPaymentsWidget(),
          ),
          const SizedBox(height: AppDimensions.spacing20),
        ],

        // Debt Summary
        if (settingsProvider.showHomeDebtSummary) ...[
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
            ),
            child: const DebtSummaryWidget(),
          ),
          const SizedBox(height: AppDimensions.spacing20),
        ],

        // Goals
        if (settingsProvider.showHomeGoals) ...[
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
            ),
            child: const GoalSummaryWidget(),
          ),
          const SizedBox(height: AppDimensions.spacing20),
        ],

        // Budget vs Expenses Chart
        if (settingsProvider.showHomeBudgetChart) ...[
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
            ),
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            decoration: BoxDecoration(
              color: context.appSurfaceLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2),
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
        ],

        // Recent Transactions
        if (settingsProvider.showHomeRecentTransactions)
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
            ),
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            decoration: BoxDecoration(
              color: context.appSurfaceLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2),
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

  Widget _buildAllWidgetsHiddenState(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.spacing24),
        decoration: BoxDecoration(
          color: context.appSurfaceLight,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: AppDimensions.iconLarge,
            ),
            const SizedBox(height: AppDimensions.spacing12),
            Text(
              'Home widgets are hidden',
              style: AppTextStyles.h3.copyWith(
                color: context.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacing8),
            Text(
              'Turn widgets back on from Settings > Home Screen.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.textSecondary,
                letterSpacing: 0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
