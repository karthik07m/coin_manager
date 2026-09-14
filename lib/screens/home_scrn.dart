import 'package:flutter/material.dart';
import '../widgets/india_setup_card.dart';
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
import '../utilities/responsive.dart';
import '../widgets/shimmer_loading.dart';
import '../utilities/functions.dart';
import 'package:flutter/services.dart';
import '../models/account.dart';
import 'account_management_screen.dart';
import 'all_transactions_screen.dart';
import '../widgets/tappable.dart';

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
      // Load live FX rates early so multi-currency totals convert app-wide.
      accountProvider.loadRates(
          Provider.of<SettingsProvider>(context, listen: false).currencyCode);
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

          // Calculate totals — scoped to the selected month. The provider's
          // transaction list is shared across tabs and may hold a wider range
          // (e.g. the List tab prefetches 3 months), so summing it unfiltered
          // showed a wrong balance until a refresh reloaded just this month.
          final monthStart =
              DateTime(_selectedMonth.year, _selectedMonth.month, 1);
          final monthEnd =
              DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
          double totalIncome = 0.0;
          double totalExpenses = 0.0;

          for (var transaction in transactions) {
            if (transaction.date.isBefore(monthStart) ||
                !transaction.date.isBefore(monthEnd)) {
              continue;
            }
            if (transaction.isTransfer) continue;
            final amt = transactionProvider.baseAmount(transaction);
            if (transaction.isExpense) {
              totalExpenses += amt;
            } else {
              totalIncome += amt;
            }
          }

          return RefreshIndicator(
            onRefresh: () => _fetchData(context, _selectedMonth),
            color: Theme.of(context).colorScheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              // Cap and center the column on tablets/desktop so cards don't
              // stretch to uncomfortable widths; a no-op on phones.
              child: context.constrainedContent(
                transactionProvider.isTransactionsLoaded
                    ? _buildContent(
                        context,
                        transactionProvider,
                        settingsProvider,
                        totalIncome,
                        totalExpenses,
                      )
                    : _buildShimmer(context, settingsProvider),
              ),
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
            SizedBox(
              height: 106,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ShimmerBox(
                    height: 106,
                    width: 154,
                    borderRadius: 16.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacing20),
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
      return Column(children: [
        const IndiaSetupCard(),
        _buildAllWidgetsHiddenState(context),
      ]);
    }
    return Column(
      children: [
        const SizedBox(height: AppDimensions.spacing16),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your overview',
                        style: AppTextStyles.h2.copyWith(
                            color: context.textPrimary, letterSpacing: -0.6)),
                    const SizedBox(height: 4),
                    Text('A little clarity for your money.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: context.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appAccentSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.account_balance_wallet_outlined,
                    color: context.appAccent, size: 24),
              ),
            ],
          ),
        ),

        // Balance Card
        const IndiaSetupCard(),
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

        // Accounts list
        _buildAccountsList(context),

        // Budget Quick Stats
        if (settingsProvider.showHomeQuickStats) ...[
          // The widget draws its own card so its ripple fills it edge to edge.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
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
              color: context.appSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: context.cardBorder,
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
              color: context.appSurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: context.cardBorder,
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
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.spacing24),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          border: context.cardBorder,
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

  Widget _buildAccountsList(BuildContext context) {
    return Consumer<AccountProvider>(
      builder: (context, accountProvider, child) {
        final accounts = accountProvider.accounts;
        if (accounts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacing16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Accounts',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AccountManagementScreen.routeName,
                      );
                    },
                    child: Text(
                      'Manage',
                      style: AppTextStyles.caption.copyWith(
                        color: context.appAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacing4),
            SizedBox(
              height: 106,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing16,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final acc = accounts[index];
                  final color = Color(Account.colorFromHex(acc.color));
                  final isLiability = acc.type.isLiability;

                  // Get currency symbol (either account-specific or system default)
                  final currencySymbol = acc.currency.isNotEmpty
                      ? currencySymbolForCode(acc.currency)
                      : Provider.of<SettingsProvider>(context, listen: false)
                          .currencySymbol;

                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    // 168, not 154: Inter sets wider than Roboto, and the
                    // default "Bank Account" name began to ellipsize.
                    width: 168,
                    child: Tappable(
                      // Opaque tint (no compositing layer): the account's
                      // colour now lives in the fill, not in an outline.
                      color: Color.alphaBlend(
                        color.withValues(alpha: context.isDark ? 0.05 : 0.07),
                        context.appSurface,
                      ),
                      borderRadius: 16,
                      pressedScale: 0.95,
                      onTap: () => HapticFeedback.selectionClick(),
                      openPage: AllTransactionsScreen(
                        initialAccountId: acc.id,
                        initialStartDate: DateTime(2000, 1, 1),
                        initialEndDate: DateTime.now(),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppDimensions.spacing12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: context.cardBorder,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor:
                                      color.withValues(alpha: 0.12),
                                  child: Icon(
                                    _getAccountIcon(acc.icon),
                                    size: 14,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    acc.name,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: context.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              UtilityFunction.formatMoney(
                                acc.currentBalance,
                                symbol: currencySymbol,
                                showDecimals: true,
                              ),
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: isLiability
                                    ? AppColors.negative
                                    : context.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isLiability ? 'Amount Owed' : 'Balance',
                              style: AppTextStyles.caption.copyWith(
                                color: context.textSecondary,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimensions.spacing20),
          ],
        );
      },
    );
  }

  IconData _getAccountIcon(String iconName) {
    switch (iconName) {
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'account_balance':
        return Icons.account_balance;
      case 'credit_card':
        return Icons.credit_card;
      case 'payment':
        return Icons.payment;
      case 'savings':
        return Icons.savings;
      default:
        return Icons.account_balance_wallet;
    }
  }
}
