import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_item.dart';
import '../widgets/no_data.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../widgets/balance_item.dart';
import '../utilities/functions.dart';
import '../utilities/constants.dart';

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
    final double position = index * 80.0;
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

      final filteredTransactions = transactions
          .where((transaction) =>
              transaction.date
                  .isAfter(_startDate.subtract(const Duration(days: 1))) &&
              transaction.date.isBefore(_endDate.add(const Duration(days: 1))))
          .toList()
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
          const SizedBox(height: AppDimensions.spacing16),
          _buildMonthScroller(),
          const SizedBox(height: AppDimensions.spacing16),
          if (transactions.isEmpty)
            const Flexible(
              child: NoData(
                title: "No transactions!",
                imagePath: "assets/nodata.png",
                textFontSize: 24,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing16,
                    vertical: AppDimensions.spacing12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBalanceDetail(
                        label: 'Income',
                        amount: transactionProvider.totalIncome,
                        icon: Icons.arrow_upward,
                        color: Colors.green,
                      ),
                      _buildBalanceDetail(
                        label: "Expenses",
                        amount: transactionProvider.totalExpenses,
                        icon: Icons.arrow_downward,
                        color: Colors.redAccent,
                      ),
                      _buildBalanceDetail(
                        label: 'Balance',
                        amount: transactionProvider.totalIncome -
                            transactionProvider.totalExpenses,
                        icon: Icons.account_balance_wallet,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
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
                return NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    if (notification is ScrollEndNotification) {
                      // Handle scroll end if needed
                    }
                    return true;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacing16),
                    itemCount: filteredTransactions.length,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    itemBuilder: (context, index) {
                      final transaction = filteredTransactions[index];
                      final showDate = index == 0 ||
                          !UtilityFunction.isSameDate(transaction.date,
                              filteredTransactions[index - 1].date);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDate)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppDimensions.spacing8,
                                  horizontal: AppDimensions.spacing8,
                                ),
                                child: Text(
                                  UtilityFunction.formatDate(transaction.date),
                                  style: AppTextStyles.h3.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMedium),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: FutureBuilder<Category?>(
                                future: Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .getCategoryDetailsById(
                                        transaction.categoryId),
                                builder: (context, snapshot) {
                                  final category = snapshot.data;
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  return TransactionItem(transaction, category);
                                },
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacing8),
                          ],
                        ),
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

  Widget _buildBalanceDetail({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: AppDimensions.iconMedium),
        const SizedBox(height: AppDimensions.spacing4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimensions.spacing4),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: AppTextStyles.amount.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthScroller() {
    final monthNames = List.generate(
      12,
      (index) => DateFormat.MMMM().format(DateTime(0, index + 1)),
    );

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
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
            child: Container(
              width: 80,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                border: isSelected
                    ? Border.all(
                        color: AppColors.primary,
                        width: 1,
                      )
                    : null,
              ),
              child: Center(
                child: Text(
                  monthNames[index],
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
