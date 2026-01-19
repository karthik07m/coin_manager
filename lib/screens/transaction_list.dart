import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_item.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../utilities/functions.dart';
import '../utilities/constants.dart';
import '../widgets/empty_transaction_state.dart';

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

  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedCategoryFilter;
  bool? _isExpenseFilter;
  bool _showFilters = false; // Collapsible filters

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _updateMonthDates(_selectedDate);

    _pageController = PageController(initialPage: _selectedDate.month - 1);
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedMonth(_selectedDate.month - 1);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
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
      _selectedDate = DateTime(_selectedDate.year, index + 1, 1);
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

      // Apply all filters
      final filteredTransactions = transactions.where((transaction) {
        // Date filter
        if (!transaction.date
                .isAfter(_startDate.subtract(const Duration(days: 1))) ||
            !transaction.date.isBefore(_endDate.add(const Duration(days: 1)))) {
          return false;
        }

        // Search filter
        if (_searchQuery.isNotEmpty) {
          final matchesTitle = transaction.title
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
          final matchesAmount =
              transaction.amount.toString().contains(_searchQuery);
          if (!matchesTitle && !matchesAmount) return false;
        }

        // Category filter
        if (_selectedCategoryFilter != null &&
            transaction.categoryId != _selectedCategoryFilter) {
          return false;
        }

        // Type filter (income/expense)
        if (_isExpenseFilter != null &&
            transaction.isExpense != _isExpenseFilter) {
          return false;
        }

        return true;
      }).toList()
        ..sort((a, b) {
          final today = DateTime.now();
          final aIsToday = UtilityFunction.isSameDate(a.date, today);
          final bIsToday = UtilityFunction.isSameDate(b.date, today);

          if (aIsToday && !bIsToday) return -1;
          if (!aIsToday && bIsToday) return 1;
          return b.date.compareTo(a.date);
        });

      return Column(
        children: [
          const SizedBox(height: AppDimensions.spacing8),

          // Compact Search/Filter Bar
          _buildCompactSearchBar(),

          // Collapsible Filters
          if (_showFilters) const SizedBox(height: AppDimensions.spacing8),
          if (_showFilters) _buildFilterChips(context),

          const SizedBox(height: AppDimensions.spacing12),
          _buildMonthScroller(),
          const SizedBox(height: AppDimensions.spacing12),
          const SizedBox(height: AppDimensions.spacing8),
          // Summary Card - More Compact
          if (filteredTransactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing16),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.spacing12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBalanceDetail(
                      label: 'Income',
                      amount: transactionProvider.totalIncome,
                      icon: Icons.arrow_upward,
                      color: AppColors.positive,
                    ),
                    Container(
                        height: 30,
                        width: 1,
                        color: Theme.of(context).dividerColor),
                    _buildBalanceDetail(
                      label: "Expenses",
                      amount: transactionProvider.totalExpenses,
                      icon: Icons.arrow_downward,
                      color: AppColors.negative,
                    ),
                    Container(
                        height: 30,
                        width: 1,
                        color: Theme.of(context).dividerColor),
                    _buildBalanceDetail(
                      label: 'Balance',
                      amount: transactionProvider.totalIncome -
                          transactionProvider.totalExpenses,
                      icon: Icons.account_balance_wallet,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppDimensions.spacing16),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: 12,
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
                      : AnimationLimiter(
                          child: ListView.builder(
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
                            itemBuilder: (context, index) {
                              final transaction = filteredTransactions[index];
                              final showDate = index == 0 ||
                                  !UtilityFunction.isSameDate(transaction.date,
                                      filteredTransactions[index - 1].date);

                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (showDate)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: AppDimensions.spacing12,
                                              horizontal:
                                                  AppDimensions.spacing8,
                                            ),
                                            child: Text(
                                              UtilityFunction.formatDate(
                                                  transaction.date),
                                              style: AppTextStyles.h3.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                          ),
                                        FutureBuilder<Category?>(
                                          future: Provider.of<CategoryProvider>(
                                                  context,
                                                  listen: false)
                                              .getCategoryDetailsById(
                                                  transaction.categoryId),
                                          builder: (context, snapshot) {
                                            final category = snapshot.data;
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return const Center(
                                                child:
                                                    SizedBox(), // Avoids flickering
                                              );
                                            }
                                            return TransactionItem(
                                                transaction, category);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildBalanceDetail({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: AppDimensions.iconMedium),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimensions.spacing4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '\$${amount.toStringAsFixed(2)}',
              style: AppTextStyles.amount.copyWith(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthScroller() {
    final monthNames = List.generate(
      12,
      (index) => DateFormat.MMM().format(DateTime(0, index + 1)),
    );

    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedDate.month - 1;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 70, // Fixed width for easier scrolling math
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent, // Cleaner look
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? null
                    : Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.3),
                        width: 1,
                      ),
              ),
              child: Center(
                child: Text(
                  monthNames[index],
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactSearchBar() {
    final hasActiveFilters =
        _selectedCategoryFilter != null || _isExpenseFilter != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing12,
                  vertical: AppDimensions.spacing8,
                ),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          // Filter toggle button
          Container(
            decoration: BoxDecoration(
              color: _showFilters || hasActiveFilters
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: IconButton(
              icon: Icon(
                Icons.filter_list,
                color: _showFilters || hasActiveFilters
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                setState(() {
                  _showFilters = !_showFilters;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final categories =
        Provider.of<CategoryProvider>(context, listen: false).categories;

    return SizedBox(
      height: 36, // Reduced from 40
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
        children: [
          // All filter
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('All', style: TextStyle(fontSize: 13)),
              selected:
                  _selectedCategoryFilter == null && _isExpenseFilter == null,
              onSelected: (selected) {
                setState(() {
                  _selectedCategoryFilter = null;
                  _isExpenseFilter = null;
                });
              },
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
          // Expense filter
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('Expenses', style: TextStyle(fontSize: 13)),
              selected: _isExpenseFilter == true,
              onSelected: (selected) {
                setState(() {
                  _isExpenseFilter = selected ? true : null;
                  _selectedCategoryFilter = null;
                });
              },
              selectedColor: AppColors.negative.withValues(alpha: 0.2),
              checkmarkColor: AppColors.negative,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
          // Income filter
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('Income', style: TextStyle(fontSize: 13)),
              selected: _isExpenseFilter == false,
              onSelected: (selected) {
                setState(() {
                  _isExpenseFilter = selected ? false : null;
                  _selectedCategoryFilter = null;
                });
              },
              selectedColor: AppColors.positive.withValues(alpha: 0.2),
              checkmarkColor: AppColors.positive,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
          // Category filters
          ...categories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label:
                    Text(category.name, style: const TextStyle(fontSize: 13)),
                avatar: SizedBox(
                  width: 18,
                  height: 18,
                  child: Image.asset(category.icon),
                ),
                selected: _selectedCategoryFilter == category.id,
                onSelected: (selected) {
                  setState(() {
                    _selectedCategoryFilter = selected ? category.id : null;
                    _isExpenseFilter = null;
                  });
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
        ],
      ),
    );
  }
}
