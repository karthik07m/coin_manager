import 'package:coin_manager/widgets/custom_nav_bar.dart'; // Import CustomNavBar
import 'package:flutter/material.dart';
import 'home_scrn.dart';
import 'transaction_list.dart';
import 'charts_screen.dart';
import 'monthly_budget_screen.dart';
import 'setting.dart';
import 'transaction_form.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../utilities/constants.dart';

class MenuScrn extends StatefulWidget {
  const MenuScrn({super.key});

  @override
  State<MenuScrn> createState() => BottomNavBarState();
}

class BottomNavBarState extends State<MenuScrn> {
  int _selectedIndex = 0;

  // Cached so widgets are built ONCE and kept alive across tab switches.
  // Previously a getter — this was creating new widget instances on every
  // setState() call, causing full subtree rebuilds on every tab tap.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Initialize screens once — never recreated.
    _screens = [
      HomePage(onTabSelected: _onItemTapped),
      const TransactionList(),
      const MonthlyBudgetScreen(),
      const ChartsScreen(),
      const SettingsScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndCheckRecurring();
    });
  }

  Future<void> _loadAndCheckRecurring() async {
    final monthlyBudgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);

    final currentMonth = DateTime.now().month.toString();

    // Load persisted data first
    await monthlyBudgetProvider.loadMonthlyData(currentMonth);

    // Check recurring budget
    if (settings.recurBudget) {
      final currentBudget = monthlyBudgetProvider.getTotalBudget(currentMonth);

      if (currentBudget == 0.0 && settings.defaultIncome > 0) {
        monthlyBudgetProvider.setTotalBudget(
            currentMonth, settings.defaultIncome);
      }
    }

    // Check recurring income transaction
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    // Check for generic recurring transactions (Subscriptions etc)
    await transactionProvider.checkAndGenerateRecurringTransactions();

    // Load upcoming transactions AFTER generating recurring instances
    await transactionProvider.loadUpcomingTransactions();

    // Load transactions for this month
    await transactionProvider.loadTransactionsFromDB(
      startDate: firstDayOfMonth,
      endDate: lastDayOfMonth,
    );

    // Auto-add monthly income ONCE per calendar month.
    // We use a persisted flag (lastAutoIncomeMonth) rather than checking the
    // in-memory transaction list. This prevents the income from being
    // re-inserted every time the app launches after the user deletes it.
    final autoIncomeKey = '${now.year}-${now.month}';
    final alreadyAddedThisMonth =
        settings.lastAutoIncomeMonth == autoIncomeKey;

    if (!alreadyAddedThisMonth &&
        settings.recurIncome &&
        settings.monthlyIncome > 0) {
      final incomeTransaction = Transaction.createNew(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: settings.monthlyIncome,
        categoryId: defaultIncomeCat,
        accountId: 1, // Default to Cash account
        title: 'Monthly Income',
        date: firstDayOfMonth,
        isExpense: false,
      );
      await transactionProvider.addTransaction(incomeTransaction);
      // Persist the flag so we don't add again this month, even after a restart
      await settings.markAutoIncomeAdded(now.year, now.month);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Monthly income added'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          SafeArea(
            // IndexedStack keeps all screens alive and simply shows/hides them.
            // This eliminates the rebuild cost entirely on tab switch.
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Navigator.of(context).pushNamed(TransactionForm.routeName),
        backgroundColor: AppColors.primary,
        elevation: AppDimensions.elevationLarge,
        shape: const CircleBorder(),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withAlpha(200),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.add,
              size: 28,
              color: Colors.white,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: CustomNavBar(
        selectedIndex: _selectedIndex,
        onItemSelected: _onItemTapped,
      ),
    );
  }
}
