import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../db/category_db_helper.dart';
import '../db/transaction_db_helper.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../providers/transaction_provider.dart';
import '../widgets/charts/categories_pie_chart.dart';
import '../widgets/charts/accounts_pie_chart.dart';
import '../providers/account_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';
import 'package:intl/intl.dart';

class ChartsScreen extends StatefulWidget {
  final ValueListenable<int> activationSignal;

  const ChartsScreen({
    super.key,
    required this.activationSignal,
  });

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _isInitialized = false;
  int _selectedChart = 0; // 0 for Expenses, 1 for Accounts
  int _categorySelectionResetToken = 0;
  List<Transaction> _previousMonthTransactions = [];
  Map<int, String> _categoryNames = {};

  @override
  void initState() {
    super.initState();
    widget.activationSignal.addListener(_handleActivation);
    // Load data when screen is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData(context, _selectedMonth);
    });
  }

  @override
  void dispose() {
    widget.activationSignal.removeListener(_handleActivation);
    super.dispose();
  }

  void _handleActivation() {
    if (!mounted) return;
    setState(() {
      _categorySelectionResetToken++;
    });
    _fetchData(context, _selectedMonth);
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
    await _loadInsightData(month);
  }

  Future<void> _loadInsightData(DateTime month) async {
    final previousMonth = DateTime(month.year, month.month - 1, 1);
    final previousStart = DateTime(previousMonth.year, previousMonth.month, 1);
    final previousEnd =
        DateTime(previousMonth.year, previousMonth.month + 1, 0, 23, 59, 59);

    final previousTransactions =
        await TransactionDBHelper().getTransactionsByType(
      startDate: previousStart,
      endDate: previousEnd,
    );
    final categories = await DBHelper().getAllCategories();
    final categoryNames = {
      for (final category in categories)
        if (category['id'] != null)
          category['id'] as int: category['name'] as String,
    };

    if (!mounted) return;
    setState(() {
      _previousMonthTransactions = previousTransactions;
      _categoryNames = categoryNames;
    });
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
                                _categorySelectionResetToken++;
                              });
                              _fetchData(context, month);
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMedium),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.appAccent
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
        title: const Text('Charts'),
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
                foregroundColor: context.appAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: Consumer3<TransactionProvider, AccountProvider, SettingsProvider>(
        builder:
            (context, transactionProvider, accountProvider, settings, child) {
          final transactions = transactionProvider.transactions;

          // Calculate total expenses
          double totalExpenses = 0.0;
          double totalIncome = 0.0;
          for (var transaction in transactions) {
            if (transaction.isTransfer) continue;
            if (transaction.isExpense) {
              totalExpenses += transaction.amount;
            } else {
              totalIncome += transaction.amount;
            }
          }

          return RefreshIndicator(
            onRefresh: () => _fetchData(context, _selectedMonth),
            color: context.appAccent,
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

                  _selectedChart == 0
                      ? _buildMonthlyInsightsCard(
                          context,
                          transactions: transactions,
                          previousTransactions: _previousMonthTransactions,
                          totalIncome: totalIncome,
                          totalExpenses: totalExpenses,
                          currencySymbol: settings.currencySymbol,
                          currencyCode: settings.currencyCode,
                        )
                      : _buildAccountInsightsCard(
                          context,
                          transactions: transactions,
                          accounts: accountProvider.accounts,
                          totalExpenses: totalExpenses,
                          currencySymbol: settings.currencySymbol,
                          currencyCode: settings.currencyCode,
                        ),
                  const SizedBox(height: AppDimensions.spacing20),

                  // Chart Card
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spacing20),
                    decoration: BoxDecoration(
                      color: context.appSurfaceLight,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusLarge),
                      border: Border.all(
                        color: context.appAccent.withValues(alpha: 0.2),
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
                            resetSelectionToken: _categorySelectionResetToken,
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
            color: isSelected ? context.appAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : context.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyInsightsCard(
    BuildContext context, {
    required List<Transaction> transactions,
    required List<Transaction> previousTransactions,
    required double totalIncome,
    required double totalExpenses,
    required String currencySymbol,
    required String currencyCode,
  }) {
    final previousExpenses = _sumByType(previousTransactions, isExpense: true);
    final previousIncome = _sumByType(previousTransactions, isExpense: false);
    final expenseDelta = totalExpenses - previousExpenses;
    final incomeDelta = totalIncome - previousIncome;
    final expensePercent = _percentChange(totalExpenses, previousExpenses);
    final topCategory = _topExpenseCategory(transactions);
    final previousTopCategory = _topExpenseCategory(previousTransactions);
    final netSavings = totalIncome - totalExpenses;
    final trendColor =
        expenseDelta <= 0 ? AppColors.positive : AppColors.negative;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: context.appSurfaceLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(
          color: context.appAccent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.appAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.query_stats,
                  color: context.appAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Insights',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _insightSummary(
                        expenseDelta: expenseDelta,
                        expensePercent: expensePercent,
                        topCategory: topCategory.name,
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.textSecondary,
                        letterSpacing: 0,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Row(
            children: [
              Expanded(
                child: _buildInsightMetric(
                  context,
                  label: 'Expense trend',
                  value: _formatSignedMoney(
                    expenseDelta,
                    currencySymbol,
                    currencyCode,
                  ),
                  detail: previousExpenses > 0
                      ? '${expensePercent.abs().toStringAsFixed(0)}% vs last month'
                      : 'No previous data',
                  color: trendColor,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: _buildInsightMetric(
                  context,
                  label: 'Net this month',
                  value: UtilityFunction.formatMoney(
                    netSavings.abs(),
                    symbol: currencySymbol,
                    currencyCode: currencyCode,
                  ),
                  detail: netSavings >= 0 ? 'saved' : 'deficit',
                  color:
                      netSavings >= 0 ? AppColors.positive : AppColors.negative,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Row(
            children: [
              Expanded(
                child: _buildInsightMetric(
                  context,
                  label: 'Top category',
                  value: topCategory.name,
                  detail: topCategory.amount > 0
                      ? UtilityFunction.formatMoney(
                          topCategory.amount,
                          symbol: currencySymbol,
                          currencyCode: currencyCode,
                        )
                      : 'No expenses',
                  color: AppColors.accentBlue,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: _buildInsightMetric(
                  context,
                  label: 'Income change',
                  value: _formatSignedMoney(
                    incomeDelta,
                    currencySymbol,
                    currencyCode,
                  ),
                  detail:
                      previousIncome > 0 ? 'vs last month' : 'No previous data',
                  color:
                      incomeDelta >= 0 ? AppColors.positive : AppColors.warning,
                ),
              ),
            ],
          ),
          if (previousTopCategory.amount > 0 && topCategory.amount > 0) ...[
            const SizedBox(height: AppDimensions.spacing12),
            Text(
              topCategory.name == previousTopCategory.name
                  ? '${topCategory.name} is still your largest spending category.'
                  : 'Top category changed from ${previousTopCategory.name} to ${topCategory.name}.',
              style: AppTextStyles.caption.copyWith(
                color: context.textSecondary,
                fontSize: 10,
                letterSpacing: 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  /// Account-focused summary shown on the "Accounts" tab (mirrors the layout
  /// of the expense insights card, but every metric is about accounts).
  Widget _buildAccountInsightsCard(
    BuildContext context, {
    required List<Transaction> transactions,
    required List<Account> accounts,
    required double totalExpenses,
    required String currencySymbol,
    required String currencyCode,
  }) {
    // Spending per account this month.
    final Map<int, double> spendByAccount = {};
    for (final t in transactions) {
      if (t.isExpense && !t.isTransfer) {
        spendByAccount[t.accountId] =
            (spendByAccount[t.accountId] ?? 0.0) + t.amount;
      }
    }

    Account? topAccount;
    double topSpend = 0.0;
    for (final a in accounts) {
      final spent = spendByAccount[a.id] ?? 0.0;
      if (spent > topSpend) {
        topSpend = spent;
        topAccount = a;
      }
    }

    // Net worth: assets minus liabilities (credit-card balances are debt).
    final totalBalance = accounts.fold(
        0.0,
        (sum, a) =>
            a.isLiability ? sum - a.currentBalance : sum + a.currentBalance);
    final accountCount = accounts.length;
    final avgPerAccount = accountCount > 0 ? totalExpenses / accountCount : 0.0;

    String money(double v) => UtilityFunction.formatMoney(
          v,
          symbol: currencySymbol,
          currencyCode: currencyCode,
        );

    final summary = accountCount == 0
        ? 'No accounts yet — add one to track balances.'
        : topAccount != null
            ? '$accountCount account${accountCount == 1 ? '' : 's'}. ${topAccount.name} spent the most this month.'
            : '$accountCount account${accountCount == 1 ? '' : 's'}. No spending this month.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: context.appSurfaceLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(
          color: context.appAccent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.appAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: context.appAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Insights',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.textSecondary,
                        letterSpacing: 0,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Row(
            children: [
              Expanded(
                child: _buildInsightMetric(
                  context,
                  label: 'Net worth',
                  value: money(totalBalance),
                  detail: 'assets − liabilities',
                  color: totalBalance >= 0
                      ? AppColors.positive
                      : AppColors.negative,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: _buildInsightMetric(
                  context,
                  label: 'Accounts',
                  value: '$accountCount',
                  detail: accountCount == 1 ? 'account' : 'accounts',
                  color: AppColors.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Row(
            children: [
              Expanded(
                child: _buildInsightMetric(
                  context,
                  label: 'Top account',
                  value: topAccount?.name ?? '—',
                  detail: topAccount != null ? money(topSpend) : 'No spending',
                  color: AppColors.accentPurple,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: _buildInsightMetric(
                  context,
                  label: 'Avg per account',
                  value: money(avgPerAccount),
                  detail: 'spent this month',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightMetric(
    BuildContext context, {
    required String label,
    required String value,
    required String detail,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          // The tile's hero number — scale down to fit rather than truncate.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTextStyles.h3.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 0,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              fontSize: 11,
              letterSpacing: 0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  double _sumByType(List<Transaction> transactions, {required bool isExpense}) {
    return transactions
        .where((transaction) =>
            transaction.isExpense == isExpense && !transaction.isTransfer)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double _percentChange(double current, double previous) {
    if (previous <= 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous) * 100;
  }

  _CategoryInsight _topExpenseCategory(List<Transaction> transactions) {
    final totals = <int, double>{};
    for (final transaction in transactions) {
      if (!transaction.isExpense || transaction.isTransfer) continue;
      totals[transaction.categoryId] =
          (totals[transaction.categoryId] ?? 0) + transaction.amount;
    }

    if (totals.isEmpty) {
      return const _CategoryInsight(name: 'None', amount: 0);
    }

    final top = totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return _CategoryInsight(
      name: _categoryNames[top.key] ?? 'Unknown',
      amount: top.value,
    );
  }

  String _formatSignedMoney(
    double value,
    String currencySymbol,
    String currencyCode,
  ) {
    final sign = value > 0
        ? '+'
        : value < 0
            ? '-'
            : '';
    return '$sign${UtilityFunction.formatMoney(
      value.abs(),
      symbol: currencySymbol,
      currencyCode: currencyCode,
    )}';
  }

  String _insightSummary({
    required double expenseDelta,
    required double expensePercent,
    required String topCategory,
  }) {
    if (expenseDelta == 0) {
      return 'Spending is flat compared with last month.';
    }
    final direction = expenseDelta > 0 ? 'up' : 'down';
    return 'Spending is $direction ${expensePercent.abs().toStringAsFixed(0)}%. $topCategory leads this month.';
  }
}

class _CategoryInsight {
  final String name;
  final double amount;

  const _CategoryInsight({
    required this.name,
    required this.amount,
  });
}
