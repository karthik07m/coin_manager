import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/category.dart';
import '../widgets/category_editor_sheet.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';
import '../providers/settings_provider.dart';
import '../utilities/budget_period.dart';
import '../utilities/budget_rules.dart';
import 'package:intl/intl.dart';

class ManageBudgetArgs {
  final DateTime? initialMonth;
  final bool autoAllocate;

  const ManageBudgetArgs({
    this.initialMonth,
    this.autoAllocate = false,
  });
}

class ManageBudgetScreen extends StatefulWidget {
  final DateTime? initialMonth;
  final bool autoAllocateOnOpen;

  const ManageBudgetScreen({
    super.key,
    this.initialMonth,
    this.autoAllocateOnOpen = false,
  });

  @override
  State<ManageBudgetScreen> createState() => _ManageBudgetScreenState();
}

class _ManageBudgetScreenState extends State<ManageBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _totalBudgetController = TextEditingController();
  final Map<String, TextEditingController> _categoryControllers = {};
  late DateTime _selectedMonth;
  bool _isSaving = false;
  bool _didAutoAllocateOnOpen = false;

  String get _monthKey => BudgetPeriod.keyFor(_selectedMonth);

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth ?? DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBudgetData();
    });
  }

  Future<void> _loadBudgetData() async {
    final budgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);

    if (categoryProvider.categories.isEmpty) {
      await categoryProvider.fetchAllCategories();
    }

    await Future.wait([
      budgetProvider.loadMonthlyData(_monthKey),
      transactionProvider.loadTransactionsFromDB(
        startDate: BudgetPeriod.startOfMonth(_selectedMonth),
        endDate: BudgetPeriod.endOfMonth(_selectedMonth),
      ),
    ]);

    if (!mounted) return;

    final totalBudget = budgetProvider.getTotalBudget(_monthKey);
    _totalBudgetController.text =
        totalBudget > 0 ? totalBudget.toStringAsFixed(2) : '';
    _syncCategoryControllers();

    if (widget.autoAllocateOnOpen && !_didAutoAllocateOnOpen) {
      _didAutoAllocateOnOpen = true;
      _autoAllocateBudgets(showSnack: false);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _syncCategoryControllers() {
    final budgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final expenseCategories =
        categoryProvider.categories.where((cat) => cat.isExpense).toList();

    final activeNames = expenseCategories.map((cat) => cat.name).toSet();
    final staleNames = _categoryControllers.keys
        .where((categoryName) => !activeNames.contains(categoryName))
        .toList();

    for (final categoryName in staleNames) {
      _categoryControllers.remove(categoryName)?.dispose();
    }

    for (final category in expenseCategories) {
      final budget = budgetProvider.getBudget(category.name, _monthKey);
      final value = budget > 0 ? budget.toStringAsFixed(2) : '';
      final controller = _categoryControllers[category.name];

      if (controller == null) {
        _categoryControllers[category.name] = TextEditingController(
          text: value,
        );
      } else if (!controller.selection.isValid) {
        controller.text = value;
      }
    }
  }

  @override
  void dispose() {
    _totalBudgetController.dispose();
    for (var controller in _categoryControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  BudgetRule _selectedBudgetRule(SettingsProvider settings) {
    final normalizedRule = settings.budgetRule.toLowerCase();
    if (settings.currencyCode == 'INR' ||
        normalizedRule.contains('india') ||
        normalizedRule.contains('essential')) {
      return indianBudgetRule;
    }

    if (normalizedRule.contains('60')) {
      return budgetRules.firstWhere(
        (rule) => rule.type == BudgetRuleType.rule60_20_20,
        orElse: () => budgetRules.first,
      );
    }

    return budgetRules.firstWhere(
      (rule) => rule.type == BudgetRuleType.rule50_30_20,
      orElse: () => budgetRules.first,
    );
  }

  double _autoAllocationBaseAmount(
    MonthlyBudgetProvider budgetProvider,
    SettingsProvider settings,
  ) {
    final currentTotalBudget = budgetProvider.getTotalBudget(_monthKey);
    if (currentTotalBudget > 0) return currentTotalBudget;
    if (settings.monthlyBudget > 0) return settings.monthlyBudget;
    if (settings.defaultIncome > 0) return settings.defaultIncome;
    return settings.monthlyIncome;
  }

  double _controllerBudgetFor(String categoryName, double fallback) {
    final controller = _categoryControllers[categoryName];
    if (controller == null) return fallback;
    final text = controller.text.trim();
    if (text.isEmpty) return 0.0;
    return double.tryParse(text) ?? 0.0;
  }

  void _autoAllocateBudgets({bool showSnack = true}) {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final budgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    final expenseCategories = categoryProvider.categories
        .where((category) => category.isExpense)
        .toList();
    final categoryNames =
        expenseCategories.map((category) => category.name).toList();

    if (categoryNames.isEmpty) {
      if (showSnack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add expense categories before auto allocating'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final baseAmount = _autoAllocationBaseAmount(
      budgetProvider,
      settingsProvider,
    );

    if (baseAmount <= 0) {
      if (showSnack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Set monthly income or budget first'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final rule = _selectedBudgetRule(settingsProvider);
    final allocations = calculateBudgetAllocation(
      totalBudget: baseAmount,
      rule: rule,
      categoryNames: categoryNames,
    );

    _totalBudgetController.text = baseAmount.toStringAsFixed(2);

    for (final category in expenseCategories) {
      final amount = allocations[category.name] ?? 0.0;
      final controller = _categoryControllers[category.name];
      final value = amount > 0 ? amount.toStringAsFixed(2) : '';

      if (controller == null) {
        _categoryControllers[category.name] = TextEditingController(
          text: value,
        );
      } else {
        controller.text = value;
      }
    }

    if (mounted) {
      setState(() {});
      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto allocated with ${rule.name}'),
            backgroundColor: AppColors.positive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveBudgets() async {
    if (_isSaving) return;

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final budgetProvider =
          Provider.of<MonthlyBudgetProvider>(context, listen: false);

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

      setState(() {
        _isSaving = true;
      });

      try {
        await budgetProvider.setTotalBudget(_monthKey, totalBudget);

        for (var entry in _categoryControllers.entries) {
          final categoryName = entry.key;
          final controller = entry.value;
          final budget = double.tryParse(controller.text) ?? 0;
          await budgetProvider.setBudget(categoryName, _monthKey, budget);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budgets saved successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving budget: $e'),
            backgroundColor: AppColors.negative,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  /// Add a new expense category, or edit one's name/icon, via the shared
  /// bottom-sheet editor (crash-free keyboard dismissal). Budgets only deal
  /// with expenses, so the type toggle is hidden.
  Future<void> _showCategoryEditor({Category? category}) async {
    final result = await showCategoryEditorSheet(
      context,
      initialName: category?.name,
      initialIcon: category?.icon,
      initialIsExpense: true,
      showTypeToggle: false,
      isEditing: category != null,
    );
    if (result == null || !mounted) return;
    await _saveCategory(existing: category, result: result);
  }

  Future<void> _saveCategory({
    Category? existing,
    required CategoryEditorResult result,
  }) async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final now = DateTime.now().toIso8601String();
    final category = Category(
      id: existing?.id,
      name: result.name,
      icon: result.icon,
      isExpense: true, // budget categories are always expenses
      budget: existing?.budget,
      createdOn: existing?.createdOn ?? now,
      modifiedOn: now,
    );

    try {
      if (existing == null) {
        await categoryProvider.addCategory(category);
      } else {
        await categoryProvider.updateCategory(category);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save category: $e'),
          backgroundColor: AppColors.negative,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDeleteCategory(Category category, double spent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appSurface,
        title: const Text('Delete category'),
        content: Text(
          spent > 0
              ? 'Delete "${category.name}"? Its ${UtilityFunction.formatMoney(spent, showDecimals: true)} of spending this month will no longer be categorized.'
              : 'Delete "${category.name}"? This removes it from every month\'s budget.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negative,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await Provider.of<CategoryProvider>(context, listen: false)
          .deleteCategory(category.id ?? 0);
      _categoryControllers.remove(category.name)?.dispose();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete category: $e'),
          backgroundColor: AppColors.negative,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyToNextMonth() async {
    final nextMonth = BudgetPeriod.nextMonth(_selectedMonth);
    final nextMonthName = DateFormat('MMMM yyyy').format(nextMonth);

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
              backgroundColor: context.appAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Copy'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      try {
        final budgetProvider =
            Provider.of<MonthlyBudgetProvider>(context, listen: false);
        await budgetProvider.copyBudgetToNextMonth(_monthKey);

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

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = DateTime(month.year, month.month);
      for (final controller in _categoryControllers.values) {
        controller.dispose();
      }
      _categoryControllers.clear();
    });
    _loadBudgetData();
  }

  void _showMonthPicker(BuildContext context) {
    var viewingYear = _selectedMonth.year;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final months = List.generate(
              12,
              (index) => DateTime(viewingYear, index + 1),
            );

            return Dialog(
              backgroundColor: context.appSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.all(AppDimensions.spacing20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Month',
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  viewingYear--;
                                });
                              },
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text(
                              '$viewingYear',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  viewingYear++;
                                });
                              },
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacing20),
                    SizedBox(
                      height: 240,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 160,
                          childAspectRatio: 1.8,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: months.length,
                        itemBuilder: (context, index) {
                          final month = months[index];
                          final isSelected =
                              month.year == _selectedMonth.year &&
                                  month.month == _selectedMonth.month;

                          return InkWell(
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _selectMonth(month);
                            },
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMedium),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.appAccent
                                    : context.appBackground,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMedium),
                                border: isSelected
                                    ? null
                                    : Border.all(color: AppColors.divider),
                              ),
                              child: Center(
                                child: Text(
                                  DateFormat('MMM').format(month),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isSelected
                                        ? Colors.white
                                        : context.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencySymbol = settingsProvider.currencySymbol;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        title: const Text('Manage Budget'),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _showMonthPicker(context),
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text(DateFormat('MMM yyyy').format(_selectedMonth)),
          ),
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
            final currentMonth = _monthKey;
            final allCategories = categoryProvider.categories;
            final categories =
                allCategories.where((cat) => cat.isExpense).toList();

            // Calculate totals from provider
            double totalAllocated = 0;
            for (var category in categories) {
              final storedBudget =
                  budgetProvider.getBudget(category.name, currentMonth);

              // Initialize controller if needed
              if (!_categoryControllers.containsKey(category.name)) {
                _categoryControllers[category.name] = TextEditingController(
                  text: storedBudget > 0 ? storedBudget.toStringAsFixed(2) : '',
                );
              }

              totalAllocated +=
                  _controllerBudgetFor(category.name, storedBudget);
            }

            final storedTotalBudget =
                budgetProvider.getTotalBudget(currentMonth);
            final totalBudgetText = _totalBudgetController.text.trim();
            final totalBudget = totalBudgetText.isEmpty
                ? 0.0
                : double.tryParse(totalBudgetText) ?? storedTotalBudget;
            final remainingBudget = totalBudget - totalAllocated;
            final progress = totalBudget > 0
                ? (totalAllocated / totalBudget).clamp(0.0, 1.0)
                : 0.0;
            final allocationRule = _selectedBudgetRule(settingsProvider);
            final autoAllocationBase = _autoAllocationBaseAmount(
              budgetProvider,
              settingsProvider,
            );

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
                                  context.appAccent,
                                  context.appAccent.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      context.appAccent.withValues(alpha: 0.3),
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
                                          onChanged: (_) => setState(() {}),
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
                                      totalAllocated > totalBudget &&
                                              totalBudget > 0
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
                          const SizedBox(height: AppDimensions.spacing16),
                          _buildAutoAllocationPanel(
                            context,
                            allocationRule,
                            autoAllocationBase,
                            currencySymbol,
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
                              final storedBudget = budgetProvider.getBudget(
                                category.name,
                                currentMonth,
                              );
                              final budget = _controllerBudgetFor(
                                category.name,
                                storedBudget,
                              );

                              // Calculate spending
                              final startDate =
                                  BudgetPeriod.startOfMonth(_selectedMonth);
                              final endDate =
                                  BudgetPeriod.endOfMonth(_selectedMonth);
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
                                                    'Spent: ${UtilityFunction.formatMoney(spent, symbol: currencySymbol, showDecimals: true)}',
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
                                            width: 100,
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
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                          // Edit / delete menu
                                          PopupMenuButton<String>(
                                            icon: Icon(
                                              Icons.more_vert,
                                              size: 20,
                                              color: context.textSecondary,
                                            ),
                                            padding: EdgeInsets.zero,
                                            splashRadius: 20,
                                            color: context.appSurface,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _showCategoryEditor(
                                                    category: category);
                                              } else if (value == 'delete') {
                                                _confirmDeleteCategory(
                                                    category, spent);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_outlined,
                                                        size: 18),
                                                    SizedBox(width: 10),
                                                    Text('Edit'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline,
                                                        size: 18,
                                                        color:
                                                            AppColors.negative),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                          color: AppColors
                                                              .negative),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
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
                                              '${UtilityFunction.formatMoney(budget - spent, symbol: currencySymbol, showDecimals: true)} left',
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
                          const SizedBox(height: 14),
                          // Add a new expense category
                          InkWell(
                            onTap: () => _showCategoryEditor(),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      context.appAccent.withValues(alpha: 0.4),
                                  width: 1.4,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 20,
                                    color: context.appAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add category',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: context.appAccent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
              onPressed: _isSaving ? null : _saveBudgets,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appAccent,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: context.appAccent.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: AppTextStyles.button,
                    ),
            ),
          ),
        ),
      ),
      resizeToAvoidBottomInset:
          false, // Prevents button from moving with keyboard
    );
  }

  Widget _buildAutoAllocationPanel(
    BuildContext context,
    BudgetRule allocationRule,
    double totalBudget,
    String currencySymbol,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: context.appAccent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.appAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: context.appAccent,
              size: AppDimensions.iconMedium,
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart allocation',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${allocationRule.description} from ${UtilityFunction.formatMoney(totalBudget, symbol: currencySymbol, showDecimals: true)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          TextButton(
            onPressed: () => _autoAllocateBudgets(),
            child: const Text('Auto Fill'),
          ),
        ],
      ),
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
