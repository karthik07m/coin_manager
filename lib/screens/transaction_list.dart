import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_item.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../models/transaction.dart';
import '../utilities/functions.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../widgets/empty_transaction_state.dart';
import '../widgets/shimmer_loading.dart';
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
  // One key per month tab so _scrollToSelectedMonth can measure its real
  // rendered position (widths vary with month-name length) instead of
  // guessing a fixed per-item pixel width.
  late List<GlobalKey> _monthItemKeys;
  int? _selectedCategoryFilter;
  bool _initialized = false;
  bool _wasVisible = false;
  bool _isJumpingToMonth = false;
  VoidCallback? _pendingSettleListener;

  // Multi-select delete
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _months = _generateMonths();
    _monthItemKeys = List.generate(_months.length, (_) => GlobalKey());
    _setMonthDateBounds(_selectedDate);

    final initialIndex = _months.indexWhere(
        (m) => m.year == _selectedDate.year && m.month == _selectedDate.month);

    _pageController = PageController(initialPage: initialIndex);
    _scrollController = ScrollController();

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToSelectedMonth(initialIndex));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load transactions once after the widget is inserted into the tree.
    // Previously this happened inside build() which violates Flutter best
    // practices (side-effects must not occur during widget construction).
    if (!_initialized) {
      _initialized = true;
      _loadTransactions();
    }

    // This screen is built inside the menu's IndexedStack while hidden, so the
    // initState centering runs before the tab is ever shown. The menu wraps
    // each tab in a TickerMode(enabled: isSelected); reading it here makes this
    // callback re-fire when the List tab becomes visible, so we re-center on
    // the current month exactly when the user lands on it.
    final visible = TickerMode.of(context);
    if (visible && !_wasVisible) {
      final index = _months.indexWhere((m) =>
          m.year == _selectedDate.year && m.month == _selectedDate.month);
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToSelectedMonth(index));
    }
    _wasVisible = visible;
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
    _pendingSettleListener?.call();
    _pageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  void _setMonthDateBounds(DateTime date) {
    _startDate = DateTime(date.year, date.month, 1);
    _endDate = DateTime(date.year, date.month + 1, 0);
  }

  // _loadTransactions is now called from didChangeDependencies and
  // _onPageChanged, never from inside build(). This avoids side-effects
  // during widget construction which caused jank.
  //
  // Loads the selected month plus one month on each side so that adjacent
  // PageView pages already have data while the user is swiping — otherwise
  // the incoming page renders empty until the DB query completes.
  Future<void> _loadTransactions() {
    final windowStart =
        DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
    final windowEnd = DateTime(_selectedDate.year, _selectedDate.month + 2, 0);
    return Provider.of<TransactionProvider>(context, listen: false)
        .loadTransactionsFromDB(
      startDate: windowStart,
      endDate: windowEnd,
      totalsStartDate: _startDate,
      totalsEndDate: _endDate,
    );
  }

  /// Defers the DB reload until the PageView settles so notifyListeners()
  /// doesn't force a full rebuild mid-animation. The newly selected month is
  /// already in the loaded window, so the visible page has data immediately;
  /// this reload only prefetches the new neighbour month.
  void _reloadWhenSettled() {
    if (!_pageController.hasClients) {
      _loadTransactions();
      return;
    }
    final scrolling = _pageController.position.isScrollingNotifier;
    if (!scrolling.value) {
      _loadTransactions();
      return;
    }
    _pendingSettleListener?.call();
    void listener() {
      if (!scrolling.value) {
        scrolling.removeListener(listener);
        _pendingSettleListener = null;
        if (mounted) _loadTransactions();
      }
    }

    _pendingSettleListener = () => scrolling.removeListener(listener);
    scrolling.addListener(listener);
  }

  /// Centers month tab [index] in the scroller. Uses the tab's actual
  /// rendered position (via its GlobalKey) rather than an assumed per-item
  /// pixel width, since tab width varies with month-name length. On a cold
  /// app start the tab may not be laid out on the very first frame — retry
  /// on the following frames instead of silently giving up.
  void _scrollToSelectedMonth(int index, {int retriesLeft = 5}) {
    if (index < 0 || index >= _monthItemKeys.length) return;
    final ctx = _monthItemKeys[index].currentContext;
    if (ctx == null) {
      if (retriesLeft > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToSelectedMonth(index, retriesLeft: retriesLeft - 1);
          }
        });
      }
      return;
    }
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    // Programmatic jumps (month bar taps) handle selection themselves;
    // reacting to every intermediate page here caused repeated setState +
    // month-bar animateTo restarts, which janked distant jumps.
    if (_isJumpingToMonth) return;
    setState(() {
      _selectedDate = _months[index];
      _setMonthDateBounds(_selectedDate);
    });
    _scrollToSelectedMonth(index);
    _reloadWhenSettled();
  }

  /// Called when a month is tapped in the month bar. For distant months,
  /// animateToPage would scroll through and build every intermediate page,
  /// firing _onPageChanged for each one. Instead: jump instantly next to the
  /// target and animate a single page transition.
  Future<void> _goToMonth(int index) async {
    if (!_pageController.hasClients) return;
    final currentIndex = _pageController.page?.round() ??
        _months.indexWhere((m) =>
            m.year == _selectedDate.year && m.month == _selectedDate.month);
    if (index == currentIndex) return;

    setState(() {
      _selectedDate = _months[index];
      _setMonthDateBounds(_selectedDate);
    });
    _scrollToSelectedMonth(index);
    // Load right away so the target month's data is usually ready before the
    // one-page animation below finishes.
    _loadTransactions();

    _isJumpingToMonth = true;
    try {
      if ((index - currentIndex).abs() > 1) {
        _pageController.jumpToPage(index > currentIndex ? index - 1 : index + 1);
      }
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } finally {
      _isJumpingToMonth = false;
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<Transaction> _filteredTransactionsForMonth(
    List<Transaction> transactions,
    DateTime month,
  ) {
    final startDate = DateTime(month.year, month.month, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);

    return transactions.where((transaction) {
      final inRange = !transaction.date.isBefore(startDate) &&
          transaction.date.isBefore(nextMonth);
      if (!inRange) return false;

      if (_selectedCategoryFilter != null &&
          transaction.categoryId != _selectedCategoryFilter) {
        return false;
      }

      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  ({double income, double expense}) _totalsFor(
    List<Transaction> transactions,
  ) {
    final provider = context.read<TransactionProvider>();
    double income = 0;
    double expense = 0;

    for (final transaction in transactions) {
      if (transaction.isTransfer) continue;
      final amt = provider.baseAmount(transaction);
      if (transaction.isExpense) {
        expense += amt;
      } else {
        income += amt;
      }
    }

    return (income: income, expense: expense);
  }

  Map<DateTime, ({double income, double expense})> _dailyTotalsFor(
    List<Transaction> transactions,
  ) {
    final totals = <DateTime, ({double income, double expense})>{};
    final provider = context.read<TransactionProvider>();

    for (final transaction in transactions) {
      if (transaction.isTransfer) continue;
      final day = _dateOnly(transaction.date);
      final amt = provider.baseAmount(transaction);
      final current = totals[day] ?? (income: 0.0, expense: 0.0);
      totals[day] = transaction.isExpense
          ? (
              income: current.income,
              expense: current.expense + amt,
            )
          : (
              income: current.income + amt,
              expense: current.expense,
            );
    }

    return totals;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionProvider, CategoryProvider>(
        builder: (context, transactionProvider, categoryProvider, child) {
      // Show shimmer skeleton while first load is in progress.
      // This replaces the jarring empty → content flash.
      if (!transactionProvider.isTransactionsLoaded) {
        return Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            _buildMonthScroller(),
            const SizedBox(height: 16),
            Expanded(child: _buildTransactionShimmer()),
          ],
        );
      }

      final transactions = transactionProvider.transactions;
      final selectedTransactions =
          _filteredTransactionsForMonth(transactions, _selectedDate);
      final totals = _totalsFor(selectedTransactions);
      final balance = totals.income - totals.expense;
      final categoryMap = categoryProvider.categoryMap;

      return PopScope(
        canPop: !_selectionMode,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selectionMode) _exitSelection();
        },
        child: Column(
          children: [
            // Custom Header with Search & Filter
            _buildHeader(),

          const SizedBox(height: AppDimensions.spacing8),
          _buildMonthScroller(),
          const SizedBox(height: AppDimensions.spacing8),

          // Compact Summary Card
          _buildCompactSummary(totals.income, totals.expense, balance),

          const SizedBox(height: AppDimensions.spacing16),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _months.length,
              itemBuilder: (context, pageIndex) {
                final pageTransactions = _filteredTransactionsForMonth(
                  transactions,
                  _months[pageIndex],
                );
                final dailyTotals = _dailyTotalsFor(pageTransactions);

                return RefreshIndicator(
                  onRefresh: () async {
                    await _loadTransactions();
                  },
                  color: context.appAccent,
                  // Fades between empty state and list (e.g. when data for a
                  // far month arrives just after a jump) instead of popping.
                  // Cheap: animates the whole page once, not per row.
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.015),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: pageTransactions.isEmpty
                        ? Stack(
                            key: ValueKey(
                              'empty_${_months[pageIndex].year}_${_months[pageIndex].month}',
                            ),
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
                          key: PageStorageKey(
                            'transaction_list_${_months[pageIndex].year}_${_months[pageIndex].month}',
                          ),
                          padding: const EdgeInsets.fromLTRB(
                            AppDimensions.spacing16,
                            0,
                            AppDimensions.spacing16,
                            100, // Bottom padding for Nav Bar
                          ),
                          itemCount: pageTransactions.length,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          cacheExtent: 500, // Pre-render items offscreen
                          itemBuilder: (context, index) {
                            final transaction = pageTransactions[index];
                            final showDate = index == 0 ||
                                !UtilityFunction.isSameDate(transaction.date,
                                    pageTransactions[index - 1].date);
                            final dailyTotal =
                                dailyTotals[_dateOnly(transaction.date)];

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
                                        final totalAmount =
                                            (dailyTotal?.income ?? 0) -
                                                (dailyTotal?.expense ?? 0);
                                        final totalColor = totalAmount > 0
                                            ? AppColors.positive
                                            : totalAmount < 0
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
                                              '${totalAmount >= 0 ? '+' : ''}${UtilityFunction.addCommaWithSign(totalAmount.abs(), currencySymbol: settings.currencySymbol, currencyCode: settings.currencyCode)}',
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
                                // No entry animation here: PageView rebuilds
                                // pages while swiping, so a staggered entry
                                // animation replays on every swipe and leaves
                                // rows invisible mid-drag.
                                RepaintBoundary(
                                  child: TransactionItem(
                                    transaction,
                                    categoryMap[transaction.categoryId],
                                    key: ValueKey('item_${transaction.id}'),
                                    selectionMode: _selectionMode,
                                    selected:
                                        _selectedIds.contains(transaction.id),
                                    onLongPress: () =>
                                        _enterSelection(transaction.id),
                                    onSelectToggle: () =>
                                        _toggleSelection(transaction.id),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                  ),
                );
              },
            ),
          ),
          ],
        ),
      );
    });
  }

  void _enterSelection(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 24),
            const SizedBox(width: 8),
            Text('Delete $count transaction${count == 1 ? '' : 's'}?',
                style: AppTextStyles.h3),
          ],
        ),
        content: Text(
          'This action cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: context.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.negative)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<TransactionProvider>();
    final ids = _selectedIds.toList();
    for (final id in ids) {
      await provider.deleteTransaction(id);
    }
    if (!mounted) return;
    _exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.appSurface,
        content: Text(
          '$count transaction${count == 1 ? '' : 's'} deleted',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (_selectionMode) {
      return Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 0),
        color: context.appBackground,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.close, color: context.textPrimary),
              onPressed: _exitSelection,
            ),
            Text(
              '${_selectedIds.length} selected',
              style: AppTextStyles.h1
                  .copyWith(fontWeight: FontWeight.w800, fontSize: 24),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Delete selected',
              icon: Icon(Icons.delete_outline, color: AppColors.negative),
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      color: context.appBackground,
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
                      ? context.appAccent
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
            // Rolls the value to its new total when the month changes,
            // instead of snapping.
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: amount),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, animatedAmount, _) {
                final formatted = UtilityFunction.formatMoney(
                    animatedAmount.abs(),
                    symbol: currency.symbol,
                    showDecimals: true);
                return Text(
                  isBalance && animatedAmount < 0 ? '-$formatted' : formatted,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                );
              },
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
      // A plain Row (not ListView.builder) so every tab is always laid out —
      // _scrollToSelectedMonth needs each tab's real GlobalKey context to
      // measure its position, which lazy-built list items wouldn't have
      // until scrolled into view.
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (int index = 0; index < _months.length; index++)
              _buildMonthTab(index),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthTab(int index) {
    final monthDate = _months[index];
    final isSelected = monthDate.year == _selectedDate.year &&
        monthDate.month == _selectedDate.month;
    final colorScheme = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final isCurrentYear = monthDate.year == now.year;

    final monthStyle = isSelected
        ? TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)
        : TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface.withValues(alpha: 0.6));

    return GestureDetector(
      key: _monthItemKeys[index],
      onTap: () => _goToMonth(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: isCurrentYear
              ? AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  style: monthStyle,
                  child: Text(DateFormat.MMMM().format(monthDate)),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      style: monthStyle,
                      child: Text(DateFormat.MMMM().format(monthDate)),
                    ),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: isSelected
                            ? context.textSecondary
                            : colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      child: Text(DateFormat.y().format(monthDate)),
                    ),
                  ],
                ),
        ),
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
                ? context.appAccent.withValues(
                    alpha: 0.15) // Changed .withValues to .withOpacity
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(
                        alpha: 0.5), // Changed .withValues to .withOpacity
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? context.appAccent : Colors.transparent,
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
                  color: isSelected ? context.appAccent : context.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shimmer skeleton shown while transactions load for the first time.
  Widget _buildTransactionShimmer() {
    return ShimmerLoading(
      isLoading: true,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: 7,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              ShimmerCircle(size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(
                        height: 14, width: double.infinity, borderRadius: 8),
                    const SizedBox(height: 8),
                    ShimmerBox(height: 12, width: 120, borderRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ShimmerBox(height: 16, width: 60, borderRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}
