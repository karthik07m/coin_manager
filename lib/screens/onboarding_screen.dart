import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../widgets/calculator_field.dart';
import '../utilities/constants.dart';
import '../utilities/budget_rules.dart';
import '../utilities/budget_period.dart';
import '../utilities/functions.dart';
import '../services/notification_service.dart';

class OnboardingScreen extends StatefulWidget {
  static const routeName = '/onboarding';

  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const int _pageCount = 5;

  final PageController _pageController = PageController();
  final TextEditingController _incomeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 0;
  bool _recurIncome = false;
  int _selectedIncomeDay = 1; // Day of month for recurring income
  double _savingsPercentage = 20.0; // Default 20% savings
  Map<String, double> _budgetAllocation = {};
  bool _isCompleting = false;

  String _selectedCurrency = 'INR';
  String _selectedCurrencySymbol = '₹';

  final List<Map<String, String>> _currencies = [
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee', 'flag': '🇮🇳'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar', 'flag': '🇺🇸'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro', 'flag': '🇪🇺'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound', 'flag': '🇬🇧'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen', 'flag': '🇯🇵'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar', 'flag': '🇦🇺'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar', 'flag': '🇨🇦'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan', 'flag': '🇨🇳'},
  ];

  List<Map<String, String>> get _filteredCurrencies {
    if (_searchController.text.isEmpty) return _currencies;
    return _currencies.where((currency) {
      final query = _searchController.text.toLowerCase();
      return currency['code']!.toLowerCase().contains(query) ||
          currency['name']!.toLowerCase().contains(query);
    }).toList();
  }

  BudgetRule get _selectedBudgetRule =>
      _selectedCurrency == 'INR' ? indianBudgetRule : budgetRules.first;

  double get _income =>
      double.tryParse(_incomeController.text.replaceAll(',', '')) ?? 0.0;

  bool get _canContinue {
    // Income step requires a valid income; everything else is always valid.
    if (_currentPage == 2) return _income > 0;
    return true;
  }

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late AnimationController _celebrateController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    // Gentle breathing animation for the welcome icon.
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    // Drives the confetti + check mark on the final page.
    _celebrateController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _searchController.addListener(() => setState(() {}));
    // Live-update the Continue button and money math as income is typed.
    _incomeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _incomeController.dispose();
    _searchController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _celebrateController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    setState(() {
      _fadeController.reset();
    });
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    if (page == _pageCount - 1) {
      _celebrateController.forward(from: 0);
    }
  }

  void _nextPage() {
    if (!_canContinue) return;
    if (_currentPage < _pageCount - 1) {
      HapticFeedback.selectionClick();
      _goToPage(_currentPage + 1);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      HapticFeedback.selectionClick();
      _goToPage(_currentPage - 1);
    }
  }

  void _selectCurrency(Map<String, String> currency) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCurrency = currency['code']!;
      _selectedCurrencySymbol = currency['symbol']!;
    });
    // Auto-advance shortly after picking — one less tap.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted && _currentPage == 1) {
        _goToPage(2);
      }
    });
  }

  ({String emoji, String label}) get _savingsPersona {
    final p = _savingsPercentage;
    if (p == 0) return (emoji: '🌱', label: 'Every journey starts somewhere');
    if (p < 10) return (emoji: '🌱', label: 'Small steps still count');
    if (p < 20) return (emoji: '👍', label: 'Solid and steady');
    if (p < 30) return (emoji: '💪', label: 'Smart saver');
    if (p < 40) return (emoji: '🔥', label: 'Impressive discipline');
    return (emoji: '🚀', label: 'Super saver mode');
  }

  Future<void> _calculateAllocation() async {
    final income = _income;
    final budget = income * (1 - _savingsPercentage / 100);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    await categoryProvider.fetchAllCategories();
    final categoryNames = categoryProvider.categories
        .where((cat) => cat.isExpense)
        .map((cat) => cat.name)
        .toList();

    setState(() {
      _budgetAllocation = calculateBudgetAllocation(
        totalBudget: budget,
        rule: _selectedBudgetRule,
        categoryNames: categoryNames,
      );
    });
  }

  /// Minimal setup for people in a hurry — saves the currency, marks
  /// onboarding done, and lets them configure everything later in Settings.
  Future<void> _skipOnboarding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Skip setup?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'No problem! You can set your income and budget anytime from Settings.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Keep going',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Skip for now',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    await settingsProvider.setCurrency(
        _selectedCurrency, _selectedCurrencySymbol);
    await settingsProvider.completeOnboarding(
      income: 0,
      budget: 0,
      budgetRule: _selectedBudgetRule.name,
      recurIncome: false,
      recurBudget: false,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    final income = _income;

    if (income <= 0) {
      // Shouldn't happen (income step is gated), but guard anyway.
      _goToPage(2);
      return;
    }

    setState(() => _isCompleting = true);
    HapticFeedback.mediumImpact();

    // Calculate budget based on savings percentage
    final budget = income * (1 - _savingsPercentage / 100);

    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final monthlyBudgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);

    // Save currency to settings
    await settingsProvider.setCurrency(
        _selectedCurrency, _selectedCurrencySymbol);

    // Save to settings
    await settingsProvider.completeOnboarding(
      income: income,
      budget: budget,
      budgetRule: _selectedBudgetRule.name,
      recurIncome: _recurIncome,
      recurBudget: true, // Always apply budget monthly
      incomeDay: _selectedIncomeDay,
    );

    // Create Income transaction
    final incomeTransaction = Transaction.createNew(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: income,
      categoryId: defaultIncomeCat,
      accountId: 1, // Default to Cash account
      title: 'Monthly Income',
      date: DateTime.now(),
      isExpense: false,
    );
    await transactionProvider.addTransaction(incomeTransaction);

    // Apply budget to current month
    final currentMonth = BudgetPeriod.keyFor(DateTime.now());
    await monthlyBudgetProvider.setTotalBudget(currentMonth, budget);

    // Apply category allocations
    await _calculateAllocation();
    for (var entry in _budgetAllocation.entries) {
      await monthlyBudgetProvider.setBudget(
          entry.key, currentMonth, entry.value);
    }

    if (!mounted) return;

    // Ask for notification permissions
    await _askForNotifications();

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  Future<void> _askForNotifications() async {
    final bool? shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.notifications_active,
                  color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            const Text(
              'Stay on Track',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Enable notifications to get daily reminders to log your expenses. This helps you stay consistent with your budget!',
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Maybe Later',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Enable Notifications'),
          ),
        ],
      ),
    );

    if (shouldRequest == true && mounted) {
      final notificationService = NotificationService();
      await notificationService.requestPermissions();
      // Schedule default daily reminder at 8pm
      await notificationService.scheduleDailyReminder(hour: 20, minute: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress Indicator + Skip
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: List.generate(_pageCount, (index) {
                          final isActive = index <= _currentPage;
                          final isCurrent = index == _currentPage;
                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              height: isCurrent ? 8 : 6,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                gradient: isActive
                                    ? LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.primary,
                                          Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.7),
                                        ],
                                      )
                                    : null,
                                color: isActive
                                    ? null
                                    : Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    if (_currentPage < _pageCount - 1)
                      TextButton(
                        onPressed: _skipOnboarding,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),

              // Step label
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Step ${_currentPage + 1} of $_pageCount',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              // Page View
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    _buildWelcomePage(),
                    _buildCurrencyPage(),
                    _buildIncomePage(),
                    _buildSavingsGoalPage(),
                    _buildReadyPage(),
                  ],
                ),
              ),

              // Navigation Buttons
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    if (_currentPage > 0 && !_isCompleting)
                      TextButton.icon(
                        onPressed: _previousPage,
                        icon: Icon(Icons.arrow_back,
                            color: Colors.white.withValues(alpha: 0.8)),
                        label: Text(
                          'Back',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ),
                    const Spacer(),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _canContinue ? 1.0 : 0.45,
                      child: ElevatedButton(
                        onPressed: _isCompleting
                            ? null
                            : (_currentPage == _pageCount - 1
                                ? _completeOnboarding
                                : _nextPage),
                        style: ElevatedButton.styleFrom(
                          elevation: _canContinue ? 8 : 0,
                          shadowColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.5),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isCompleting) ...[
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Setting up...',
                                style: AppTextStyles.button.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ] else ...[
                              Text(
                                _currentPage == _pageCount - 1
                                    ? "Let's go!"
                                    : 'Continue',
                                style: AppTextStyles.button.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _currentPage == _pageCount - 1
                                    ? Icons.rocket_launch_rounded
                                    : Icons.arrow_forward,
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 64, // Account for padding
              ),
              child: AnimationLimiter(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 500),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      verticalOffset: 40,
                      child: FadeInAnimation(child: widget),
                    ),
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.96, end: 1.04).animate(
                          CurvedAnimation(
                            parent: _pulseController,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.7),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.4),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.account_balance_wallet,
                              size: 80, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        'Welcome to',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'Coinly',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your smart financial companion',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '⚡ Setup takes under a minute',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildFeature(Icons.insights, 'Smart expense tracking'),
                      const SizedBox(height: 20),
                      _buildFeature(Icons.pie_chart, 'Visual spending insights'),
                      const SizedBox(height: 20),
                      _buildFeature(Icons.savings, 'Achieve savings goals'),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeature(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Select Currency 💱',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap one — we\'ll move you right along',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search currency...',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  prefixIcon: Icon(Icons.search,
                      color: Colors.white.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimationLimiter(
                child: ListView.builder(
                  itemCount: _filteredCurrencies.length,
                  itemBuilder: (context, index) {
                    final currency = _filteredCurrencies[index];
                    final isSelected = _selectedCurrency == currency['code'];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 350),
                      child: SlideAnimation(
                        verticalOffset: 30,
                        child: FadeInAnimation(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              onTap: () => _selectCurrency(currency),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: isSelected
                                    ? BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        width: 1.5,
                                      )
                                    : BorderSide.none,
                              ),
                              tileColor: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.05),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          colors: [
                                            Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.7),
                                          ],
                                        )
                                      : null,
                                  color: isSelected
                                      ? null
                                      : Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    currency['flag']!,
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                ),
                              ),
                              title: Text(
                                '${currency['code']}  ·  ${currency['symbol']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Text(
                                currency['name']!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 14,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 28)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomePage() {
    final income = _income;
    final perDay = income / 30;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Monthly Income 💰',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'How much do you earn each month?',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 40),
            CalculatorTextFormField(
              controller: _incomeController,
              currencySymbol: _selectedCurrencySymbol,
            ),
            const SizedBox(height: 12),
            // Live feedback: nudge until valid, fun fact once entered.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: income > 0
                  ? Container(
                      key: const ValueKey('income_fact'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '✨ That\'s about ${UtilityFunction.formatMoney(perDay, symbol: _selectedCurrencySymbol, currencyCode: _selectedCurrency)} a day to work with',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Padding(
                      key: const ValueKey('income_hint'),
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Tap the field above to enter your income',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _recurIncome
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.repeat,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Auto-add monthly',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Automatically add income each month',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _recurIncome,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _recurIncome = val;
                      });
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),

            // Income Day Selector (shown when recurring is enabled)
            if (_recurIncome) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Income Day',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Day of month to receive income',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: DropdownButton<int>(
                        value: _selectedIncomeDay,
                        underline: const SizedBox(),
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        items: List.generate(28, (index) {
                          final day = index + 1;
                          return DropdownMenuItem(
                            value: day,
                            child: Text('Day $day'),
                          );
                        }),
                        onChanged: (day) {
                          setState(() {
                            _selectedIncomeDay = day!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsGoalPage() {
    final income = _income;
    final savingsAmount = income * (_savingsPercentage / 100);
    final budgetAmount = income - savingsAmount;
    final persona = _savingsPersona;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Savings Goal 🎯',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Drag the slider — watch your plan take shape',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 40),
            // Percentage Slider
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_savingsPercentage.toInt()}%',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 8,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 16),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 28),
                      activeTrackColor: Theme.of(context).colorScheme.primary,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                      thumbColor: Colors.white,
                      overlayColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3),
                    ),
                    child: Slider(
                      value: _savingsPercentage,
                      min: 0,
                      max: 50,
                      divisions: 50,
                      onChanged: (value) {
                        if (value.toInt() != _savingsPercentage.toInt()) {
                          HapticFeedback.selectionClick();
                        }
                        setState(() {
                          _savingsPercentage = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Savings persona — reacts live to the slider.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Row(
                      key: ValueKey(persona.emoji + persona.label),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(persona.emoji,
                            style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 10),
                        Text(
                          persona.label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Summary Cards
            if (income > 0) ...[
              _buildSummaryCard(
                'Monthly Budget',
                budgetAmount,
                Icons.shopping_bag,
                const Color(0xFF4ECDC4),
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(
                'Monthly Savings',
                savingsAmount,
                Icons.savings,
                const Color(0xFF95E1D3),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyPage() {
    final income = _income;
    final savingsAmount = income * (_savingsPercentage / 100);
    final budgetAmount = income - savingsAmount;

    String money(double v) => UtilityFunction.formatMoney(
          v,
          symbol: _selectedCurrencySymbol,
          currencyCode: _selectedCurrency,
        );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Confetti burst behind the content
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _celebrateController,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(
                    progress: _celebrateController.value,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      const Color(0xFF4ECDC4),
                      const Color(0xFFFFD700),
                      const Color(0xFFFF6B6B),
                      const Color(0xFF95E1D3),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // Animated check
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _celebrateController,
                    curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.7),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 64, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'You\'re all set! 🎉',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Here\'s the plan we built together',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),
                AnimationLimiter(
                  child: Column(
                    children: AnimationConfiguration.toStaggeredList(
                      duration: const Duration(milliseconds: 400),
                      childAnimationBuilder: (widget) => SlideAnimation(
                        verticalOffset: 30,
                        child: FadeInAnimation(child: widget),
                      ),
                      children: [
                        _buildPlanRow(
                          '💱',
                          'Currency',
                          '$_selectedCurrency ($_selectedCurrencySymbol)',
                        ),
                        const SizedBox(height: 12),
                        _buildPlanRow('💰', 'Monthly income', money(income)),
                        const SizedBox(height: 12),
                        _buildPlanRow(
                          '🎯',
                          'Savings goal',
                          '${_savingsPercentage.toInt()}%  ·  ${money(savingsAmount)}',
                        ),
                        const SizedBox(height: 12),
                        _buildPlanRow(
                          '🛍️',
                          'Spending budget',
                          money(budgetAmount),
                        ),
                        if (_recurIncome) ...[
                          const SizedBox(height: 12),
                          _buildPlanRow(
                            '🔁',
                            'Income auto-added',
                            'Day $_selectedIncomeDay of each month',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'You can change any of this later in Settings',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanRow(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 15,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                // Animate value changes as the slider moves.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: amount, end: amount),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, value, _) => Text(
                    UtilityFunction.formatMoney(
                      value,
                      symbol: _selectedCurrencySymbol,
                      currencyCode: _selectedCurrency,
                      showDecimals: true,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight confetti burst: deterministic particles fanning out from the
/// top-center, fading as [progress] goes 0 → 1. No external packages.
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _ConfettiPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final random = math.Random(7); // fixed seed → stable particle layout
    final origin = Offset(size.width / 2, size.height * 0.18);
    final paint = Paint();

    for (int i = 0; i < 60; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final velocity = 60 + random.nextDouble() * 220;
      final rotation = random.nextDouble() * 2 * math.pi;
      final color = colors[i % colors.length];
      final isRect = i.isEven;

      // Ease-out travel with slight gravity pull.
      final t = Curves.easeOut.transform(progress);
      final dx = math.cos(angle) * velocity * t;
      final dy = math.sin(angle) * velocity * t + 120 * progress * progress;

      paint.color = color.withValues(alpha: (1 - progress).clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(rotation + progress * 4 * (i.isEven ? 1 : -1));
      if (isRect) {
        canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: 8, height: 4), paint);
      } else {
        canvas.drawCircle(Offset.zero, 3, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
