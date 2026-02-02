import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';
import '../widgets/transaction_item.dart';

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
            icon: const Icon(Icons.tune),
            onPressed: _showFilterSheet,
            tooltip: 'Category Filter',
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
                  ],
                ),
              ),
            ),
          ),

          // Transactions list
          Expanded(
            child: Consumer2<TransactionProvider, CategoryProvider>(
              builder: (context, transactionProvider, categoryProvider, child) {
                final transactions = transactionProvider.transactions;

                // Apply filters
                final filteredTransactions = transactions.where((t) {
                  // Search filter
                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    if (!t.title.toLowerCase().contains(query) &&
                        !t.amount.toString().contains(query)) {
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

                  return true;
                }).toList()
                  ..sort((a, b) => b.date.compareTo(a.date));

                if (filteredTransactions.isEmpty) {
                  return _buildEmptyState();
                }

                // Calculate totals
                final totalIncome = filteredTransactions
                    .where((t) => !t.isExpense)
                    .fold(0.0, (sum, t) => sum + t.amount);
                final totalExpense = filteredTransactions
                    .where((t) => t.isExpense)
                    .fold(0.0, (sum, t) => sum + t.amount);

                return Column(
                  children: [
                    // Summary bar
                    _buildSummaryBar(
                        filteredTransactions.length, totalIncome, totalExpense),

                    // Transaction list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction = filteredTransactions[index];
                          final showDate = index == 0 ||
                              !UtilityFunction.isSameDate(transaction.date,
                                  filteredTransactions[index - 1].date);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showDate) _buildDateHeader(transaction.date),
                              Builder(
                                builder: (context) {
                                  // Find category synchronously from loaded categories
                                  final category =
                                      categoryProvider.categories.firstWhere(
                                    (c) => c.id == transaction.categoryId,
                                    orElse: () =>
                                        categoryProvider.categories.first,
                                  );
                                  return TransactionItem(transaction, category);
                                },
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
                  ? AppColors.primary
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
                color: isSelected ? Colors.white : context.textSecondary,
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
      chipColor = AppColors.primary;
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

  void _showFilterSheet() {
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
                      setState(() => _selectedCategoryId = null);
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
    final isSelected = _selectedCategoryId == id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedCategoryId = id);
          setSheetState(() {});
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
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
