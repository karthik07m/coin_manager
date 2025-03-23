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

class TransactionList extends StatefulWidget {
  const TransactionList({Key? key}) : super(key: key);

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
          const SizedBox(height: 5),
          _buildMonthScroller(),
          transactions.isEmpty
              ? const Flexible(
                  child: NoData(
                    title: "No transactions!",
                    imagePath: "assets/nodata.png",
                    textFontSize: 24,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    BalanceDetail(
                      label: 'Income',
                      amount: transactionProvider.totalIncome,
                      icon: Icons.arrow_upward,
                      color: Colors.green,
                    ),
                    BalanceDetail(
                      label: "Expenses",
                      amount: transactionProvider.totalExpenses,
                      icon: Icons.arrow_downward,
                      color: Colors.redAccent,
                    ),
                    BalanceDetail(
                      label: 'Balance',
                      amount: transactionProvider.totalIncome -
                          transactionProvider.totalExpenses,
                      icon: Icons.account_balance_wallet,
                      color: Colors.blue,
                    ),
                  ],
                ),
          const SizedBox(height: 10),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: 12,
              itemBuilder: (context, pageIndex) {
                return ListView.builder(
                  itemCount: filteredTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = filteredTransactions[index];
                    final showDate = index == 0 ||
                        !UtilityFunction.isSameDate(transaction.date,
                            filteredTransactions[index - 1].date);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 16.0),
                            child: Text(
                              UtilityFunction.formatDate(transaction.date),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        FutureBuilder<Category?>(
                          future: Provider.of<CategoryProvider>(context,
                                  listen: false)
                              .getCategoryDetailsById(transaction.categoryId),
                          builder: (context, snapshot) {
                            final category = snapshot.data;
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            }
                            return TransactionItem(transaction, category);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildMonthScroller() {
    final monthNames = List.generate(
      12,
      (index) => DateFormat.MMMM().format(DateTime(0, index + 1)),
    );

    return SizedBox(
      height: 60,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: monthNames.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedDate.month == index + 1;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    monthNames[index],
                    style: TextStyle(
                      fontSize: 18,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 4.0),
                      height: 2,
                      width: 20,
                      color: Theme.of(context).primaryColor,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
