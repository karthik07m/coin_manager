import 'package:coin_manager/widgets/custom_nav_bar.dart'; // Import CustomNavBar
import 'package:flutter/material.dart';
import 'home_scrn.dart';
import 'transaction_list.dart';
import 'charts_screen.dart';
import 'monthly_budget_screen.dart';
import 'setting.dart';
import 'ai_assistant_screen.dart';
import 'transaction_form.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/id_generator.dart';
import '../providers/monthly_budget_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/account_provider.dart';
import '../models/transaction.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/budget_period.dart';
import '../services/bill_reminder_scheduler.dart';

class MenuScrn extends StatefulWidget {
  const MenuScrn({super.key});

  @override
  State<MenuScrn> createState() => BottomNavBarState();
}

class BottomNavBarState extends State<MenuScrn>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _tabDirection = 1;
  final ValueNotifier<int> _chartsActivationSignal = ValueNotifier<int>(0);
  late final AnimationController _tabAnimationController;
  late final Animation<double> _tabAnimation;

  // Cached so widgets are built ONCE and kept alive across tab switches.
  // Previously a getter — this was creating new widget instances on every
  // setState() call, causing full subtree rebuilds on every tab tap.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _tabAnimationController = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _tabAnimation = CurvedAnimation(
      parent: _tabAnimationController,
      curve: Curves.easeOutCubic,
    );
    _tabAnimationController.value = 1;

    // Initialize screens once — never recreated.
    _screens = [
      HomePage(onTabSelected: _onItemTapped),
      const TransactionList(),
      const MonthlyBudgetScreen(),
      ChartsScreen(activationSignal: _chartsActivationSignal),
      const AiAssistantScreen(reserveBottomNavigationSpace: true),
      const SettingsScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndCheckRecurring();
    });
  }

  @override
  void dispose() {
    _tabAnimationController.dispose();
    _chartsActivationSignal.dispose();
    super.dispose();
  }

  Future<void> _loadAndCheckRecurring() async {
    final monthlyBudgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);

    final currentMonth = BudgetPeriod.keyFor(DateTime.now());

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
    if (!accountProvider.isLoaded) {
      await accountProvider.loadAccounts();
    }

    // Auto-add monthly income ONCE per calendar month.
    // We use a persisted flag (lastAutoIncomeMonth) rather than checking the
    // in-memory transaction list. This prevents the income from being
    // re-inserted every time the app launches after the user deletes it.
    final autoIncomeKey = '${now.year}-${now.month}';
    final alreadyAddedThisMonth = settings.lastAutoIncomeMonth == autoIncomeKey;

    if (!alreadyAddedThisMonth &&
        settings.recurIncome &&
        settings.monthlyIncome > 0) {
      final incomeTransaction = Transaction.createNew(
        id: newId(),
        amount: settings.monthlyIncome,
        categoryId: defaultIncomeCat,
        accountId: accountProvider.defaultAccount?.id ?? 1,
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

    // Refresh bill/debt due-date reminders now that recurring instances and
    // this month's data are up to date. No-ops if reminders are disabled.
    await BillReminderScheduler().reschedule();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _tabDirection = index > _selectedIndex ? 1 : -1;
      if (index == 3) {
        _chartsActivationSignal.value++;
      }
      _selectedIndex = index;
    });
    _tabAnimationController.forward(from: 0);
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
            child: AnimatedBuilder(
              animation: _tabAnimation,
              child: IndexedStack(
                index: _selectedIndex,
                children: List.generate(
                  _screens.length,
                  (index) => TickerMode(
                    enabled: index == _selectedIndex,
                    child: RepaintBoundary(
                      child: _screens[index],
                    ),
                  ),
                ),
              ),
              builder: (context, child) {
                final offset = Tween<Offset>(
                  begin: Offset(0.035 * _tabDirection, 0),
                  end: Offset.zero,
                ).evaluate(_tabAnimation);
                final opacity = Tween<double>(
                  begin: 0.92,
                  end: 1,
                ).evaluate(_tabAnimation);

                return FadeTransition(
                  opacity: AlwaysStoppedAnimation(opacity),
                  child: FractionalTranslation(
                    translation: offset,
                    child: child,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 4
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.of(context).pushNamed(
                TransactionForm.routeName,
              ),
              backgroundColor: context.appAccent,
              elevation: AppDimensions.elevationLarge,
              shape: const CircleBorder(),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      context.appAccent,
                      context.appAccent.withAlpha(200),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.add,
                    size: 28,
                    color: Theme.of(context).colorScheme.onPrimary,
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
