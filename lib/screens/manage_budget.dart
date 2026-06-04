import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';
import '../providers/settings_provider.dart';

class ManageBudgetScreen extends StatefulWidget {
  const ManageBudgetScreen({super.key});

  @override
  State<ManageBudgetScreen> createState() => _ManageBudgetScreenState();
}

class _ManageBudgetScreenState extends State<ManageBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _totalBudgetController = TextEditingController();
  final Map<String, TextEditingController> _categoryControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBudgetData();
    });
  }

  void _loadBudgetData() {
    final budgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);
    final currentMonth = DateTime.now().month.toString();

    final totalBudget = budgetProvider.getTotalBudget(currentMonth);
    _totalBudgetController.text =
        totalBudget > 0 ? totalBudget.toStringAsFixed(2) : '';
  }

  @override
  void dispose() {
    _totalBudgetController.dispose();
    for (var controller in _categoryControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _saveBudgets() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final budgetProvider =
          Provider.of<MonthlyBudgetProvider>(context, listen: false);
      final currentMonth = DateTime.now().month.toString();

      final totalBudget = double.tryParse(_totalBudgetController.text) ?? 0;

      // Calculate total allocated
      double totalAllocated = 0;
      for (var entry in _categoryControllers.entries) {
        final controller = entry.value;
        final budget = double.tryParse(controller.text) ?? 0;
        totalAllocated += budget;
      }

      if (totalAllocated > totalBudget) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Total of category budgets exceeds monthly budget'),
            backgroundColor: AppColors.negative,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Save total budget
      budgetProvider.setTotalBudget(currentMonth, totalBudget);

      // Save category budgets
      for (var entry in _categoryControllers.entries) {
        final categoryName = entry.key;
        final controller = entry.value;
        final budget = double.tryParse(controller.text) ?? 0;
        budgetProvider.setBudget(categoryName, currentMonth, budget);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Budgets saved successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _copyToNextMonth() async {
    final currentMonth = DateTime.now().month.toString();
    final currentMonthInt = DateTime.now().month;
    final nextMonthInt = currentMonthInt == 12 ? 1 : currentMonthInt + 1;
    final nextMonthName = _getMonthName(nextMonthInt);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy Budget to Next Month'),
        content: Text(
          'This will copy all budget settings from the current month to $nextMonthName. Any existing budgets for $nextMonthName will be overwritten.\n\nDo you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Copy'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final budgetProvider =
            Provider.of<MonthlyBudgetProvider>(context, listen: false);
        await budgetProvider.copyBudgetToNextMonth(currentMonth);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Budget copied to $nextMonthName successfully'),
              backgroundColor: AppColors.positive,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error copying budget: $e'),
              backgroundColor: AppColors.negative,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  String _getMonthName(int month) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return monthNames[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        title: const Text('Manage Budget', style: AppTextStyles.h3),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copy to Next Month',
            onPressed: _copyToNextMonth,
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer3<CategoryProvider, MonthlyBudgetProvider,
            TransactionProvider>(
          builder: (context, categoryProvider, budgetProvider,
              transactionProvider, child) {
            final currentMonth = DateTime.now().month.toString();
            final allCategories = categoryProvider.categories;
            final categories =
                allCategories.where((cat) => cat.isExpense).toList();

            // Calculate totals from provider
            double totalAllocated = 0;
            for (var category in categories) {
              final budget =
                  budgetProvider.getBudget(category.name, currentMonth);
              totalAllocated += budget;

              // Initialize controller if needed
              if (!_categoryControllers.containsKey(category.name)) {
                _categoryControllers[category.name] = TextEditingController(
                  text: budget > 0 ? budget.toStringAsFixed(2) : '',
                );
              }
            }

            final totalBudget = budgetProvider.getTotalBudget(currentMonth);
            final remainingBudget = totalBudget - totalAllocated;
            final progress = totalBudget > 0
                ? (totalAllocated / totalBudget).clamp(0.0, 1.0)
                : 0.0;

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDimensions.spacing16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Professional Budget Header Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Monthly Budget',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      currencySymbol,
                                      style: AppTextStyles.h2.copyWith(
                                        color: Colors.white,
                                        fontSize: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: IntrinsicWidth(
                                        child: TextFormField(
                                          controller: _totalBudgetController,
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.h1.copyWith(
                                            color: Colors.white,
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: '0.00',
                                            hintStyle: TextStyle(
                                              color: Colors.white60,
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Progress bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.3),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progress > 1.0
                                          ? AppColors.negative
                                          : Colors.white,
                                    ),
                                    minHeight: 10,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Summary row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildWhiteSummaryItem(
                                        'Allocated',
                                        totalAllocated,
                                        currencySymbol,
                                      ),
                                    ),
                                    Container(
                                      height: 40,
                                      width: 1,
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                    ),
                                    Expanded(
                                      child: _buildWhiteSummaryItem(
                                        'Remaining',
                                        remainingBudget,
                                        currencySymbol,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'CATEGORY BUDGETS',
                                style: AppTextStyles.caption.copyWith(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                '${categories.length} Categories',
                                style: AppTextStyles.caption.copyWith(
                                  color: context.textSecondary
                                      .withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Professional Category Cards
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: categories.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final budget = budgetProvider.getBudget(
                                  category.name, currentMonth);

                              // Calculate spending
                              final now = DateTime.now();
                              final startDate =
                                  DateTime(now.year, now.month, 1);
                              final endDate =
                                  DateTime(now.year, now.month + 1, 0);
                              final spent =
                                  transactionProvider.getCategorySpending(
                                      category.id!, startDate, endDate);
                              final percentSpent =
                                  budget > 0 ? (spent / budget) : 0.0;

                              // Determine color
                              Color progressColor;
                              if (percentSpent >= 1.0) {
                                progressColor = AppColors.negative;
                              } else if (percentSpent >= 0.8) {
                                progressColor = AppColors.warning;
                              } else {
                                progressColor = AppColors.positive;
                              }

                              return RepaintBoundary(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: context.appSurface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: budget > 0
                                          ? progressColor.withValues(alpha: 0.2)
                                          : AppColors.divider
                                              .withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      // Top row: Icon, Name, Input
                                      Row(
                                        children: [
                                          // Icon
                                          Container(
                                            width: 48,
                                            height: 48,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: progressColor.withValues(
                                                  alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Image.asset(
                                              category.icon,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          // Category name
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  category.name,
                                                  style: AppTextStyles.bodyLarge
                                                      .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                if (budget > 0) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Spent: ${UtilityFunction.formatMoney(spent, symbol: currencySymbol)}',
                                                    style: AppTextStyles.caption
                                                        .copyWith(
                                                      color: progressColor,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Budget input
                                          SizedBox(
                                            width: 110,
                                            child: TextFormField(
                                              controller: _categoryControllers[
                                                  category.name],
                                              textAlign: TextAlign.end,
                                              style: AppTextStyles.h3.copyWith(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '0',
                                                hintStyle: TextStyle(
                                                  color: context.textSecondary
                                                      .withValues(alpha: 0.4),
                                                ),
                                                prefixText: '$currencySymbol ',
                                                prefixStyle: TextStyle(
                                                  color: context.textSecondary,
                                                  fontSize: 15,
                                                ),
                                                isDense: true,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: BorderSide.none,
                                                ),
                                                filled: true,
                                                fillColor:
                                                    context.appSurfaceLight,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 14,
                                                ),
                                              ),
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Progress bar (only if budget is set)
                                      if (budget > 0) ...[
                                        const SizedBox(height: 14),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: percentSpent.clamp(0.0, 1.0),
                                            backgroundColor: AppColors.divider
                                                .withValues(alpha: 0.2),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    progressColor),
                                            minHeight: 8,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${(percentSpent * 100).toStringAsFixed(0)}% used',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                color: context.textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                            Text(
                                              '${UtilityFunction.formatMoney(budget - spent, symbol: currencySymbol)} left',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                color: progressColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      // Fixed bottom save button - stays at bottom even when keyboard opens
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            child: ElevatedButton(
              onPressed: _saveBudgets,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
      resizeToAvoidBottomInset:
          false, // Prevents button from moving with keyboard
    );
  }

  Widget _buildWhiteSummaryItem(
      String label, double amount, String currencySymbol) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          UtilityFunction.addCommaWithSign(amount,
              currencySymbol: currencySymbol),
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}
