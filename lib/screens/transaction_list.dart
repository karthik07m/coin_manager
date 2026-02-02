import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_item.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';

import '../utilities/functions.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../widgets/empty_transaction_state.dart';
import 'all_transactions_screen.dart';

class TransactionList extends StatefulWidget {
  const TransactionList({super.key});

  @override
  State<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  late final PageController _pageController;
  late final ScrollController _scrollController;
  late DateTime _selectedDate;
  late DateTime _startDate;
  late DateTime _endDate;
  late List<DateTime> _months;
  int? _selectedCategoryFilter;
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _months = _generateMonths();
    _updateMonthDates(_selectedDate);

    final initialIndex = _months.indexWhere(
        (m) => m.year == _selectedDate.year && m.month == _selectedDate.month);

    _pageController = PageController(initialPage: initialIndex);
    _scrollController = ScrollController();

    // Scroll to show January of current year as first visible month
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      final januaryIndex =
          _months.indexWhere((m) => m.year == now.year && m.month == 1);
      if (januaryIndex != -1 && _scrollController.hasClients) {
        _scrollController.jumpTo(januaryIndex * 78.0);
      }
    });
  }

  List<DateTime> _generateMonths() {
    final now = DateTime.now();
    final List<DateTime> months = [];

    // Previous year last 4 months
    for (int i = 9; i <= 12; i++) {
      months.add(DateTime(now.year - 1, i));
    }

    // Current year all 12 months
    for (int i = 1; i <= 12; i++) {
      months.add(DateTime(now.year, i));
    }

    // Future year first 4 months
    for (int i = 1; i <= 4; i++) {
      months.add(DateTime(now.year + 1, i));
    }

    return months;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  void _updateMonthDates(DateTime date) {
    _startDate = DateTime(date.year, date.month, 1);
    _endDate = DateTime(date.year, date.month + 1, 0);
    _loadTransactions();
  }

  void _loadTransactions() {
    Provider.of<TransactionProvider>(context, listen: false)
        .loadTransactionsFromDB(startDate: _startDate, endDate: _endDate);
  }

  void _scrollToSelectedMonth(int index) {
    if (!_scrollController.hasClients) return;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double position = index * 78.0; // 70 width + 8 total margin
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double offset =
        (position - (screenWidth / 2) + 40.0).clamp(0, maxScroll);

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedDate = _months[index];
      _updateMonthDates(_selectedDate);
      _scrollToSelectedMonth(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
        builder: (context, transactionProvider, child) {
      final transactions = transactionProvider.transactions;

      if (!transactionProvider.isTransactionsLoaded) {
        _loadTransactions();
      }

      // Apply filters
      final filteredTransactions = transactions.where((transaction) {
        // Date filter
        if (!transaction.date
                .isAfter(_startDate.subtract(const Duration(days: 1))) ||
            !transaction.date.isBefore(_endDate.add(const Duration(days: 1)))) {
          return false;
        }

        // Category filter
        if (_selectedCategoryFilter != null &&
            transaction.categoryId != _selectedCategoryFilter) {
          return false;
        }

        return true;
      }).toList()
        ..sort((a, b) {
          // Sort by date descending
          return b.date.compareTo(a.date);
        });

      // Calculate totals for visible transactions
      double income = 0;
      double expense = 0;
      for (var t in filteredTransactions) {
        if (t.isExpense) {
          expense += t.amount;
        } else {
          income += t.amount;
        }
      }
      double balance = income - expense;

      return Column(
        children: [
          // Custom Header with Search & Filter
          _buildHeader(),

          const SizedBox(height: AppDimensions.spacing8),
          _buildMonthScroller(),
          const SizedBox(height: AppDimensions.spacing8),

          // Compact Summary Card
          _buildCompactSummary(income, expense, balance),

          const SizedBox(height: AppDimensions.spacing16),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _months.length,
              itemBuilder: (context, pageIndex) {
                return RefreshIndicator(
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 500));
                    _loadTransactions();
                  },
                  color: AppColors.primary,
                  child: filteredTransactions.isEmpty
                      ? Stack(
                          children: [
                            ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                            ),
                            const Positioned.fill(
                              child: EmptyTransactionState(),
                            ),
                          ],
                        )
                      : ListView.builder(
                          key: const PageStorageKey('transaction_list'),
                          padding: const EdgeInsets.fromLTRB(
                            AppDimensions.spacing16,
                            0,
                            AppDimensions.spacing16,
                            100, // Bottom padding for Nav Bar
                          ),
                          itemCount: filteredTransactions.length,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          cacheExtent: 500, // Pre-render items offscreen
                          itemBuilder: (context, index) {
                            final transaction = filteredTransactions[index];
                            final showDate = index == 0 ||
                                !UtilityFunction.isSameDate(transaction.date,
                                    filteredTransactions[index - 1].date);

                            return Column(
                              key: ValueKey(transaction.id),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showDate)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppDimensions.spacing12,
                                      horizontal: AppDimensions.spacing8,
                                    ),
                                    child: Consumer<SettingsProvider>(
                                      builder: (context, settings, _) {
                                        // Calculate daily total
                                        final dailyTransactions =
                                            filteredTransactions.where((t) =>
                                                UtilityFunction.isSameDate(
                                                    t.date, transaction.date));
                                        double dailyIncome = 0;
                                        double dailyExpense = 0;
                                        for (var t in dailyTransactions) {
                                          if (t.isExpense) {
                                            dailyExpense += t.amount;
                                          } else {
                                            dailyIncome += t.amount;
                                          }
                                        }
                                        final dailyTotal =
                                            dailyIncome - dailyExpense;
                                        final totalColor = dailyTotal > 0
                                            ? AppColors.positive
                                            : dailyTotal < 0
                                                ? AppColors.negative
                                                : context.textSecondary;

                                        return Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              UtilityFunction.formatDate(
                                                  transaction.date),
                                              style: AppTextStyles.h3.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                            Text(
                                              '${dailyTotal >= 0 ? '+' : ''}${UtilityFunction.addCommaWithSign(dailyTotal.abs(), currencySymbol: settings.currencySymbol)}',
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
                                                color: totalColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                // Use Consumer to get category without FutureBuilder
                                Consumer<CategoryProvider>(
                                  builder: (context, categoryProvider, _) {
                                    final category = categoryProvider.categories
                                        .where((cat) =>
                                            cat.id == transaction.categoryId)
                                        .firstOrNull;
                                    return TransactionItem(
                                        transaction, category,
                                        key:
                                            ValueKey('item_${transaction.id}'));
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Transactions',
            style: AppTextStyles.h1
                .copyWith(fontWeight: FontWeight.w800, fontSize: 28),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _selectedCategoryFilter != null
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined,
                  color: _selectedCategoryFilter != null
                      ? AppColors.primary
                      : context.textPrimary,
                ),
                onPressed: _showFilterCategorySheet,
              ),
              IconButton(
                icon: Icon(
                  Icons.search,
                  color: context.textPrimary,
                ),
                onPressed: () {
                  Navigator.of(context)
                      .pushNamed(AllTransactionsScreen.routeName);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSummary(double income, double expense, double balance) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSummaryItem(
                Icons.arrow_drop_down, expense, AppColors.negative),
            _buildSummaryItem(Icons.arrow_drop_up, income, AppColors.positive),
            _buildSummaryItem(null, balance, context.textPrimary,
                isBalance: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData? icon, double amount, Color color,
      {bool isBalance = false}) {
    return Selector<SettingsProvider, ({String symbol, String code})>(
      selector: (_, settings) => (
        symbol: settings.currencySymbol,
        code: settings.currencyCode,
      ),
      builder: (context, currency, _) {
        final formatted = UtilityFunction.formatMoney(amount.abs(),
            symbol: currency.symbol, showDecimals: true);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBalance)
              Text(' = ',
                  style: TextStyle(
                      color: context.textSecondary,
                      fontWeight: FontWeight.bold))
            else
              Icon(icon, color: color, size: 20),
            Text(
              isBalance && amount < 0 ? '-$formatted' : formatted,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthScroller() {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(top: 10),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _months.length,
        itemBuilder: (context, index) {
          final monthDate = _months[index];
          final isSelected = monthDate.year == _selectedDate.year &&
              monthDate.month == _selectedDate.month;
          final colorScheme = Theme.of(context).colorScheme;

          final now = DateTime.now();
          final isCurrentYear = monthDate.year == now.year;

          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                border: isSelected
                    ? Border(
                        bottom:
                            BorderSide(color: colorScheme.primary, width: 2))
                    : null,
              ),
              child: Center(
                child: isCurrentYear
                    ? Text(
                        DateFormat.MMMM().format(monthDate),
                        style: isSelected
                            ? TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary)
                            : TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6)),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat.MMMM().format(monthDate),
                            style: isSelected
                                ? TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary)
                                : TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6)),
                          ),
                          Text(
                            DateFormat.y().format(monthDate),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: isSelected
                                  ? context.textSecondary
                                  : colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFilterCategorySheet() {
    final categories =
        Provider.of<CategoryProvider>(context, listen: false).categories;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter by Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedCategoryFilter = null);
                      Navigator.pop(context);
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCategoryChip(
                      null, 'All Categories', null, setSheetState),
                  ...categories.map((cat) => _buildCategoryChip(
                      cat.id, cat.name, cat.icon, setSheetState)),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
      int? id, String name, String? icon, StateSetter setSheetState) {
    final isSelected = _selectedCategoryFilter == id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedCategoryFilter = id);
          setSheetState(() {});
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(
                    alpha: 0.15) // Changed .withValues to .withOpacity
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(
                        alpha: 0.5), // Changed .withValues to .withOpacity
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Image.asset(icon, width: 18, height: 18),
                const SizedBox(width: 6),
              ],
              Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : context.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
