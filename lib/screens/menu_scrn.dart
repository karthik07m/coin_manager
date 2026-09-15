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
import '../services/app_update_service.dart';
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
      AiAssistantScreen(
        reserveBottomNavigationSpace: true,
        onOpenCharts: () => _onItemTapped(3),
      ),
      const SettingsScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndCheckRecurring();
      // Best-effort and silent when the app wasn't installed from Play.
      AppUpdateService().checkForUpdate();
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

    // Roll the budget into the new month: carry last month's figures (total
    // and category split) forward so every month starts tracked, and only
    // fall back to the recurring amount when there's no earlier month yet.
    if (settings.recurBudget) {
      final rolledFrom =
          await monthlyBudgetProvider.rollOverBudget(currentMonth);

      if (rolledFrom == null) {
        final currentBudget =
            monthlyBudgetProvider.getTotalBudget(currentMonth);

        if (currentBudget == 0.0 && settings.defaultIncome > 0) {
          await monthlyBudgetProvider.setTotalBudget(
              currentMonth, settings.defaultIncome);
        }
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
          // A downloaded update waits here rather than in a dialog: the
          // install is ready whenever the user is, and nothing blocks the
          // screen they were using.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: ValueListenableBuilder<bool>(
                valueListenable: AppUpdateService().readyToInstall,
                builder: (context, ready, _) {
                  if (!ready) return const SizedBox.shrink();
                  return _buildUpdateReadyBanner(context);
                },
              ),
            ),
          ),
        ],
      ),
      // AI (4) has its own input; Settings (5) has nothing to add and the
      // button sat on top of its switches.
      floatingActionButton: _selectedIndex == 4 || _selectedIndex == 5
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.of(context).pushNamed(
                TransactionForm.routeName,
              ),
              tooltip: 'Add transaction',
              backgroundColor: context.appAccent,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.add_rounded, size: 28),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: CustomNavBar(
        selectedIndex: _selectedIndex,
        onItemSelected: _onItemTapped,
      ),
    );
  }

  Widget _buildUpdateReadyBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: context.appAccent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.system_update, color: context.appAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Update downloaded. Restart to install.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => AppUpdateService().dismiss(),
            child: const Text('Later'),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () => AppUpdateService().completeUpdate(),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appAccent,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }
}
