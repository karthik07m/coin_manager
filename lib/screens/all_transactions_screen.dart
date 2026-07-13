import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';
import '../widgets/transaction_item.dart';
import '../widgets/animated_list_item.dart';

enum TransactionSortOption {
  newest,
  oldest,
  highestAmount,
  lowestAmount,
}

class AllTransactionsScreen extends StatefulWidget {
  static const routeName = '/all-transactions';

  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final int? initialCategoryId;
  final int? initialAccountId;
  final bool hideFiltersInitially;

  const AllTransactionsScreen({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    this.initialCategoryId,
    this.initialAccountId,
    this.hideFiltersInitially = false,
  });

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Filters
  bool? _isExpenseFilter; // null = all, true = expenses, false = income
  int? _selectedCategoryId;
  int? _selectedAccountId;
  double? _minAmount;
  double? _maxAmount;
  bool? _recurringFilter;
  bool? _receiptFilter;
  TransactionSortOption _sortOption = TransactionSortOption.newest;
  String _selectedDatePreset = 'This Month';
  late bool _showFilters;

  @override
  void initState() {
    super.initState();

    // Use initial values if provided, otherwise default to current month
    if (widget.initialStartDate != null && widget.initialEndDate != null) {
      _startDate = widget.initialStartDate!;
      _endDate = widget.initialEndDate!;
      _selectedDatePreset = 'Custom';
    } else {
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0);
    }

    if (widget.initialCategoryId != null) {
      _selectedCategoryId = widget.initialCategoryId;
    }

    if (widget.initialAccountId != null) {
      _selectedAccountId = widget.initialAccountId;
    }

    // Hide filters initially if requested (e.g., when coming from drill-down)
    _showFilters = !widget.hideFiltersInitially;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      if (categoryProvider.categories.isEmpty) {
        categoryProvider.fetchAllCategories();
      }
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);
      if (!accountProvider.isLoaded) {
        accountProvider.loadAccounts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadTransactions() {
    Provider.of<TransactionProvider>(context, listen: false)
        .loadTransactionsFromDB(startDate: _startDate, endDate: _endDate);
  }

  int get _advancedFilterCount {
    var count = 0;
    if (_selectedCategoryId != null) count++;
    if (_selectedAccountId != null) count++;
    if (_minAmount != null) count++;
    if (_maxAmount != null) count++;
    if (_recurringFilter != null) count++;
    if (_receiptFilter != null) count++;
    if (_sortOption != TransactionSortOption.newest) count++;
    return count;
  }

  bool get _hasAnyFilter {
    return _searchQuery.trim().isNotEmpty ||
        _isExpenseFilter != null ||
        _selectedDatePreset != 'This Month' ||
        _advancedFilterCount > 0;
  }

  void _clearAdvancedFilters() {
    setState(() {
      _selectedCategoryId = null;
      _selectedAccountId = null;
      _minAmount = null;
      _maxAmount = null;
      _recurringFilter = null;
      _receiptFilter = null;
      _sortOption = TransactionSortOption.newest;
    });
  }

  void _clearAllFilters() {
    final now = DateTime.now();
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _isExpenseFilter = null;
      _selectedCategoryId = null;
      _selectedAccountId = null;
      _minAmount = null;
      _maxAmount = null;
      _recurringFilter = null;
      _receiptFilter = null;
      _sortOption = TransactionSortOption.newest;
      _selectedDatePreset = 'This Month';
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0);
    });
    _loadTransactions();
  }

  String _sortLabel(TransactionSortOption option) {
    switch (option) {
      case TransactionSortOption.newest:
        return 'Newest first';
      case TransactionSortOption.oldest:
        return 'Oldest first';
      case TransactionSortOption.highestAmount:
        return 'Highest amount';
      case TransactionSortOption.lowestAmount:
        return 'Lowest amount';
    }
  }

  double? _parseAmount(String value) {
    final normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _selectedDatePreset = preset;
      switch (preset) {
        case 'Today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = _startDate;
          break;
        case 'This Week':
          final weekDay = now.weekday;
          _startDate = now.subtract(Duration(days: weekDay - 1));
          _startDate =
              DateTime(_startDate.year, _startDate.month, _startDate.day);
          _endDate = now;
          break;
        case 'This Month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'Last 3 Months':
          _startDate = DateTime(now.year, now.month - 2, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'This Year':
          _startDate = DateTime(now.year, 1, 1);
          _endDate = DateTime(now.year, 12, 31);
          break;
        case 'Custom':
          // Keep current dates
          break;
      }
    });
    _loadTransactions();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _selectedDatePreset = 'Custom';
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
      _loadTransactions();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _selectedDatePreset = 'Custom';
      });
      _loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('All Transactions'),
        elevation: 0,
        actions: [
          IconButton(
            icon:
                Icon(_showFilters ? Icons.filter_list : Icons.filter_list_off),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            tooltip: _showFilters ? 'Hide Filters' : 'Show Filters',
          ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune),
                if (_advancedFilterCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.appAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _advancedFilterCount.toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterSheet,
            tooltip: 'Filters and sort',
          ),
        ],
      ),
      body: Column(
        children: [
          // Collapsible Header Section
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _showFilters ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showFilters ? 1.0 : 0.0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date Presets
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPresetChip('Today'),
                          _buildPresetChip('This Week'),
                          _buildPresetChip('This Month'),
                          _buildPresetChip('Last 3 Months'),
                          _buildPresetChip('This Year'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date pickers row
                    if (_selectedDatePreset == 'Custom') ...[
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 20, color: context.textSecondary),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('From',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: context.textSecondary)),
                              GestureDetector(
                                onTap: _selectStartDate,
                                child: Text(
                                  DateFormat('MMM dd, yyyy').format(_startDate),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(Icons.arrow_forward, size: 16),
                          ),
                          Icon(Icons.calendar_today_outlined,
                              size: 20, color: context.textSecondary),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('To',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: context.textSecondary)),
                              GestureDetector(
                                onTap: _selectEndDate,
                                child: Text(
                                  DateFormat('MMM dd, yyyy').format(_endDate),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Search bar
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: 'Search transactions...',
                          hintStyle: TextStyle(
                            color: context.textSecondary.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.search,
                              size: 20, color: context.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear,
                                      size: 18, color: context.textSecondary),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Type filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCompactTypeChip('All', null),
                          const SizedBox(width: 8),
                          _buildCompactTypeChip('Income', false),
                          const SizedBox(width: 8),
                          _buildCompactTypeChip('Expenses', true),
                        ],
                      ),
                    ),
                    if (_hasAnyFilter) ...[
                      const SizedBox(height: 12),
                      Consumer2<CategoryProvider, AccountProvider>(
                        builder:
                            (context, categoryProvider, accountProvider, _) {
                          return _buildActiveFiltersRow(
                            categoryProvider,
                            accountProvider,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Transactions list
          Expanded(
            child: Consumer3<TransactionProvider, CategoryProvider,
                AccountProvider>(
              builder: (context, transactionProvider, categoryProvider,
                  accountProvider, child) {
                final transactions = transactionProvider.transactions;
                final categoryMap = categoryProvider.categoryMap;

                // Apply filters
                final filteredTransactions = transactions.where((t) {
                  final category = categoryMap[t.categoryId];
                  final account = accountProvider.getAccountById(t.accountId);

                  // Search filter
                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.trim().toLowerCase();
                    final searchableText = [
                      t.title,
                      t.amount.toString(),
                      category?.name ?? '',
                      account?.name ?? '',
                      t.isExpense ? 'expense' : 'income',
                    ].join(' ').toLowerCase();
                    if (!searchableText.contains(query)) {
                      return false;
                    }
                  }

                  // Type filter
                  if (_isExpenseFilter != null &&
                      t.isExpense != _isExpenseFilter) {
                    return false;
                  }

                  // Category filter
                  if (_selectedCategoryId != null &&
                      t.categoryId != _selectedCategoryId) {
                    return false;
                  }

                  // Account filter
                  if (_selectedAccountId != null &&
                      t.accountId != _selectedAccountId) {
                    return false;
                  }

                  // Amount range filter
                  if (_minAmount != null && t.amount < _minAmount!) {
                    return false;
                  }
                  if (_maxAmount != null && t.amount > _maxAmount!) {
                    return false;
                  }

                  // Recurring filter
                  if (_recurringFilter != null &&
                      t.isRecurring != _recurringFilter) {
                    return false;
                  }

                  // Receipt filter
                  if (_receiptFilter != null) {
                    final hasReceipt =
                        t.receiptId != null && t.receiptId!.trim().isNotEmpty;
                    if (hasReceipt != _receiptFilter) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                switch (_sortOption) {
                  case TransactionSortOption.newest:
                    filteredTransactions
                        .sort((a, b) => b.date.compareTo(a.date));
                    break;
                  case TransactionSortOption.oldest:
                    filteredTransactions
                        .sort((a, b) => a.date.compareTo(b.date));
                    break;
                  case TransactionSortOption.highestAmount:
                    filteredTransactions
                        .sort((a, b) => b.amount.compareTo(a.amount));
                    break;
                  case TransactionSortOption.lowestAmount:
                    filteredTransactions
                        .sort((a, b) => a.amount.compareTo(b.amount));
                    break;
                }

                if (filteredTransactions.isEmpty) {
                  return _buildEmptyState();
                }

                double totalIncome = 0;
                double totalExpense = 0;
                for (final transaction in filteredTransactions) {
                  if (transaction.isTransfer) continue;
                  if (transaction.isExpense) {
                    totalExpense += transaction.amount;
                  } else {
                    totalIncome += transaction.amount;
                  }
                }

                return Column(
                  children: [
                    // Summary bar
                    _buildSummaryBar(
                        filteredTransactions.length, totalIncome, totalExpense),

                    // Transaction list
                    Expanded(
                      child: ListView.builder(
                        key: const PageStorageKey('all_transactions_list'),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: filteredTransactions.length,
                        cacheExtent: 600,
                        itemBuilder: (context, index) {
                          final transaction = filteredTransactions[index];
                          final showDate = index == 0 ||
                              !UtilityFunction.isSameDate(transaction.date,
                                  filteredTransactions[index - 1].date);

                          return Column(
                            key: ValueKey(transaction.id),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showDate) _buildDateHeader(transaction.date),
                              AnimatedListItem(
                                key: ValueKey('animated_${transaction.id}'),
                                index: index > 8 ? 8 : index,
                                child: RepaintBoundary(
                                  child: TransactionItem(
                                    transaction,
                                    categoryMap[transaction.categoryId],
                                    key: ValueKey('item_${transaction.id}'),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label) {
    final isSelected = _selectedDatePreset == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _applyDatePreset(label),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.appAccent
                  : Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : context.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTypeChip(String label, bool? isExpense) {
    final isSelected = _isExpenseFilter == isExpense;
    Color chipColor;
    if (isExpense == null) {
      chipColor = context.appAccent;
    } else if (isExpense) {
      chipColor = AppColors.negative;
    } else {
      chipColor = AppColors.positive;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _isExpenseFilter = isExpense),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? chipColor.withValues(alpha: 0.15)
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? chipColor : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? chipColor : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFiltersRow(
    CategoryProvider categoryProvider,
    AccountProvider accountProvider,
  ) {
    final category = _selectedCategoryId == null
        ? null
        : categoryProvider.categoryMap[_selectedCategoryId];
    final account = _selectedAccountId == null
        ? null
        : accountProvider.getAccountById(_selectedAccountId!);

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_searchQuery.trim().isNotEmpty)
                  _buildActiveFilterChip(
                    'Search: ${_searchQuery.trim()}',
                    () => setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    }),
                  ),
                if (_isExpenseFilter != null)
                  _buildActiveFilterChip(
                    _isExpenseFilter! ? 'Expenses' : 'Income',
                    () => setState(() => _isExpenseFilter = null),
                  ),
                if (_selectedDatePreset != 'This Month')
                  _buildActiveFilterChip(
                    _selectedDatePreset,
                    () => _applyDatePreset('This Month'),
                  ),
                if (category != null)
                  _buildActiveFilterChip(
                    category.name,
                    () => setState(() => _selectedCategoryId = null),
                  ),
                if (account != null)
                  _buildActiveFilterChip(
                    account.name,
                    () => setState(() => _selectedAccountId = null),
                  ),
                if (_minAmount != null)
                  _buildActiveFilterChip(
                    'Min ${_minAmount!.toStringAsFixed(0)}',
                    () => setState(() => _minAmount = null),
                  ),
                if (_maxAmount != null)
                  _buildActiveFilterChip(
                    'Max ${_maxAmount!.toStringAsFixed(0)}',
                    () => setState(() => _maxAmount = null),
                  ),
                if (_recurringFilter != null)
                  _buildActiveFilterChip(
                    _recurringFilter! ? 'Recurring' : 'One-time',
                    () => setState(() => _recurringFilter = null),
                  ),
                if (_receiptFilter != null)
                  _buildActiveFilterChip(
                    _receiptFilter! ? 'Has receipt' : 'No receipt',
                    () => setState(() => _receiptFilter = null),
                  ),
                if (_sortOption != TransactionSortOption.newest)
                  _buildActiveFilterChip(
                    _sortLabel(_sortOption),
                    () => setState(
                      () => _sortOption = TransactionSortOption.newest,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _clearAllFilters,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Clear'),
        ),
      ],
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.appAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.appAccent.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.appAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDeleted,
              child: Icon(
                Icons.close,
                color: context.appAccent,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar(int count, double income, double expense) {
    final currencySymbol = context.watch<SettingsProvider>().currencySymbol;
    final currencyCode = context.watch<SettingsProvider>().currencyCode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count transactions',
              style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.positive.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+${UtilityFunction.addCommaWithSign(income, currencySymbol: currencySymbol, currencyCode: currencyCode)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.positive,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.negative.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '-${UtilityFunction.addCommaWithSign(expense, currencySymbol: currencySymbol)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.negative,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        UtilityFunction.formatDate(date),
        style: TextStyle(
          fontSize: 13,
          color: context.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: context.textSecondary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No transactions found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    final categories =
        Provider.of<CategoryProvider>(context, listen: false).categories;
    final accounts =
        Provider.of<AccountProvider>(context, listen: false).accounts;
    final minAmountController = TextEditingController(
      text: _minAmount == null ? '' : _minAmount!.toStringAsFixed(0),
    );
    final maxAmountController = TextEditingController(
      text: _maxAmount == null ? '' : _maxAmount!.toStringAsFixed(0),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) => Container(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textSecondary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filters and sort',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _clearAdvancedFilters();
                        minAmountController.clear();
                        maxAmountController.clear();
                        setSheetState(() {});
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildFilterSectionTitle(Icons.sort, 'Sort'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: TransactionSortOption.values
                            .map(
                              (option) => _buildSheetChip(
                                label: _sortLabel(option),
                                isSelected: _sortOption == option,
                                onTap: () {
                                  setState(() => _sortOption = option);
                                  setSheetState(() {});
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      _buildFilterSectionTitle(
                        Icons.category_outlined,
                        'Category',
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildCategoryChip(
                            null,
                            'All categories',
                            null,
                            setSheetState,
                          ),
                          ...categories.map(
                            (cat) => _buildCategoryChip(
                              cat.id,
                              cat.name,
                              cat.icon,
                              setSheetState,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildFilterSectionTitle(
                        Icons.account_balance_wallet_outlined,
                        'Account',
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildAccountChip(
                              null, 'All accounts', setSheetState),
                          ...accounts
                              .where((account) => account.id != null)
                              .map(
                                (account) => _buildAccountChip(
                                  account.id,
                                  account.name,
                                  setSheetState,
                                ),
                              ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildFilterSectionTitle(
                        Icons.payments_outlined,
                        'Amount range',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAmountField(
                              controller: minAmountController,
                              label: 'Min',
                              onChanged: (value) {
                                setState(
                                    () => _minAmount = _parseAmount(value));
                                setSheetState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAmountField(
                              controller: maxAmountController,
                              label: 'Max',
                              onChanged: (value) {
                                setState(
                                    () => _maxAmount = _parseAmount(value));
                                setSheetState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildFilterSectionTitle(
                        Icons.repeat,
                        'Transaction details',
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildSheetChip(
                            label: 'Any schedule',
                            isSelected: _recurringFilter == null,
                            onTap: () {
                              setState(() => _recurringFilter = null);
                              setSheetState(() {});
                            },
                          ),
                          _buildSheetChip(
                            label: 'Recurring',
                            isSelected: _recurringFilter == true,
                            onTap: () {
                              setState(() => _recurringFilter = true);
                              setSheetState(() {});
                            },
                          ),
                          _buildSheetChip(
                            label: 'One-time',
                            isSelected: _recurringFilter == false,
                            onTap: () {
                              setState(() => _recurringFilter = false);
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildSheetChip(
                            label: 'Any receipt',
                            isSelected: _receiptFilter == null,
                            onTap: () {
                              setState(() => _receiptFilter = null);
                              setSheetState(() {});
                            },
                          ),
                          _buildSheetChip(
                            label: 'Has receipt',
                            isSelected: _receiptFilter == true,
                            onTap: () {
                              setState(() => _receiptFilter = true);
                              setSheetState(() {});
                            },
                          ),
                          _buildSheetChip(
                            label: 'No receipt',
                            isSelected: _receiptFilter == false,
                            onTap: () {
                              setState(() => _receiptFilter = false);
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Show transactions'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    minAmountController.dispose();
    maxAmountController.dispose();
  }

  Widget _buildFilterSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.textSecondary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? leading,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? context.appAccent.withValues(alpha: 0.15)
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? context.appAccent : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: 6),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? context.appAccent : context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.attach_money, size: 18),
        filled: true,
        fillColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.appAccent, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildAccountChip(int? id, String name, StateSetter setSheetState) {
    return _buildSheetChip(
      label: name,
      isSelected: _selectedAccountId == id,
      leading: Icon(
        id == null ? Icons.all_inbox_outlined : Icons.account_balance_wallet,
        size: 16,
        color: _selectedAccountId == id
            ? context.appAccent
            : context.textSecondary,
      ),
      onTap: () {
        setState(() => _selectedAccountId = id);
        setSheetState(() {});
      },
    );
  }

  Widget _buildCategoryChip(
      int? id, String name, String? icon, StateSetter setSheetState) {
    final isSelected = _selectedCategoryId == id;
    return _buildSheetChip(
      label: name,
      isSelected: isSelected,
      leading: icon == null
          ? Icon(
              Icons.category_outlined,
              size: 16,
              color: isSelected ? context.appAccent : context.textSecondary,
            )
          : Image.asset(
              icon,
              width: 18,
              height: 18,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.category_outlined,
                size: 16,
                color: isSelected ? context.appAccent : context.textSecondary,
              ),
            ),
      onTap: () {
        setState(() => _selectedCategoryId = id);
        setSheetState(() {});
      },
    );
  }
}
