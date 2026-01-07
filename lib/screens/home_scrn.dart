import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../widgets/charts/categories_pie_chart.dart';
import '../widgets/recent_transactions_widget.dart';
import '../utilities/constants.dart';
import 'balance_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _fetchData(BuildContext context, DateTime selectedMonth) async {
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final budgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);

    DateTime startDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
    DateTime endDate = DateTime(selectedMonth.year, selectedMonth.month + 1, 1)
        .subtract(const Duration(days: 1));

    // Load all necessary data
    await Future.wait([
      transactionProvider.loadTransactionsFromDB(
          startDate: startDate, endDate: endDate),
      categoryProvider.fetchAllCategories(),
      budgetProvider.loadMonthlyData(selectedMonth.month.toString()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return FutureBuilder(
      future: _fetchData(context, _selectedMonth),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error loading data'));
        } else {
          return Consumer<TransactionProvider>(
            builder: (context, transactionProvider, child) {
              final totalIncome = transactionProvider.totalIncome;
              final totalExpenses = transactionProvider.totalExpenses;

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Balance Card with Month Picker

                      // Balance Card

                      BalanceCard(
                        screenWidth: screenWidth,
                        totalIncome: totalIncome,
                        totalExpenses: totalExpenses,
                        selectedMonth: _selectedMonth,
                        onMonthChanged: (DateTime newMonth) {
                          setState(() {
                            _selectedMonth = newMonth;
                          });
                          _fetchData(context, newMonth);
                        },
                      ),

                      const SizedBox(height: AppDimensions.spacing24),

                      // Recent Transactions
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: AppDimensions.spacing16),
                        child: RecentTransactionsWidget(),
                      ),

                      const SizedBox(height: AppDimensions.spacing20),

                      // Categories Pie Chart
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: CategoriesPieChart(
                            screenHeight:
                                MediaQuery.of(context).size.height * 0.8,
                            categories: transactionProvider.categories,
                            totalExpenses: totalExpenses,
                          ),
                        ),
                      ),

                      // Placeholder for additional features
                    ],
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }
}
