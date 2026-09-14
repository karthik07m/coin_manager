import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/budget_scope.dart';
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
  /// Cent-level overshoot from splitting a budget across categories isn't
  /// worth warning about; anything larger is a real over-allocation.
  static const double _overAllocationTolerance = 0.01;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _totalBudgetController = TextEditingController();
  final Map<String, TextEditingController> _categoryControllers = {};
  late DateTime _selectedMonth;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _didAutoAllocateOnOpen = false;

  /// What this month's budget is measured against.
  BudgetScope _scope = BudgetScope.allExpenses;

  /// Set when this month had nothing saved and the form was seeded from an
  /// earlier month. Cleared as soon as the user saves.
  String? _seededFromLabel;

  /// Whether the month being edited already has a saved budget.
  bool _monthHasSavedBudget = false;

  String get _monthKey => BudgetPeriod.keyFor(_selectedMonth);

  String get _monthLabel => DateFormat('MMMM yyyy').format(_selectedMonth);

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

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

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

    final hasSavedBudget = await budgetProvider.hasBudgetFor(_monthKey);
    if (!mounted) return;

    final totalBudget = budgetProvider.getTotalBudget(_monthKey);
    _totalBudgetController.text = _formatAmount(totalBudget);
    _scope = budgetProvider.getScope(_monthKey);
    _syncCategoryControllers(fromStoredValues: true);

    // A month you've never budgeted starts from the last month you did, so
    // every month stays tracked without retyping it. Nothing is written until
    // the user saves.
    String? seededFrom;
    if (!hasSavedBudget) {
      final previous = await budgetProvider.previousMonthBudget(_monthKey);
      if (!mounted) return;

      if (previous != null && !previous.isEmpty) {
        _applySnapshot(previous);
        seededFrom = previous.label;
      }
    }

    if (widget.autoAllocateOnOpen && !_didAutoAllocateOnOpen) {
      _didAutoAllocateOnOpen = true;
      _autoAllocateBudgets(showSnack: false);
      seededFrom = null;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _monthHasSavedBudget = hasSavedBudget;
        _seededFromLabel = seededFrom;
      });
    }
  }

  String _formatAmount(double amount) =>
      amount > 0 ? amount.toStringAsFixed(2) : '';

  /// Loads a saved month's figures into the form without writing anything.
  void _applySnapshot(MonthBudgetSnapshot snapshot) {
    _totalBudgetController.text = _formatAmount(snapshot.totalBudget);
    _scope = snapshot.scope;

    for (final entry in _categoryControllers.entries) {
      entry.value.text = _formatAmount(snapshot.categoryBudgets[entry.key] ?? 0);
    }
  }

  void _syncCategoryControllers({bool fromStoredValues = false}) {
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
      final value = _formatAmount(budget);
      final controller = _categoryControllers[category.name];

      if (controller == null) {
        _categoryControllers[category.name] = TextEditingController(
          text: value,
        );
      } else if (fromStoredValues) {
        // Reloading a month replaces whatever is on screen — otherwise a
        // field the user had focused keeps the previous month's number.
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
    final allocations = roundAllocationToTotal(
      calculateBudgetAllocation(
        totalBudget: baseAmount,
        rule: rule,
        categoryNames: categoryNames,
      ),
      baseAmount,
    );

    _totalBudgetController.text = baseAmount.toStringAsFixed(2);

    for (final category in expenseCategories) {
      final amount = allocations[category.name] ?? 0.0;
      final controller = _categoryControllers[category.name];
      final value = _formatAmount(amount);

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

  double get _enteredAllocated => _enteredCategoryBudgets()
      .values
      .fold<double>(0, (sum, value) => sum + value);

  bool get _totalDiffersFromAllocated =>
      (_enteredTotalBudget - _enteredAllocated).abs() >
      _overAllocationTolerance;

  /// Switching to category scope changes what the monthly figure means: it
  /// stops being a spending cap and becomes the total of the envelopes. If
  /// the two disagree, offer to reconcile them rather than silently measuring
  /// category spending against an unrelated number.
  Future<void> _selectScope(BudgetScope scope) async {
    if (_scope == scope) return;
    setState(() => _scope = scope);

    if (scope != BudgetScope.budgetedCategories) return;

    final allocated = _enteredAllocated;
    final total = _enteredTotalBudget;
    if (allocated <= 0) return;
    if ((total - allocated).abs() <= _overAllocationTolerance) return;

    await _offerToMatchTotalToCategories(total, allocated);
  }

  Future<void> _offerToMatchTotalToCategories(
    double total,
    double allocated,
  ) async {
    final currencySymbol =
        Provider.of<SettingsProvider>(context, listen: false).currencySymbol;
    String money(double value) => UtilityFunction.formatMoney(
          value,
          symbol: currencySymbol,
          showDecimals: true,
        );

    final match = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appSurface,
        title: const Text('Match budget to your categories?'),
        content: Text(
          total <= 0
              ? 'Your category budgets add up to ${money(allocated)}. With only budgeted categories counting, that total is usually the monthly budget.'
              : 'Your category budgets add up to ${money(allocated)}, but the monthly budget is ${money(total)}.\n\n'
                  'With only budgeted categories counting, spending would be measured against ${money(total)} — a figure those categories were never meant to fill.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(total <= 0 ? 'Not now' : 'Keep ${money(total)}'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appAccent,
              foregroundColor: Colors.white,
            ),
            child: Text('Set to ${money(allocated)}'),
          ),
        ],
      ),
    );

    if (match != true || !mounted) return;

    setState(() {
      _totalBudgetController.text = allocated.toStringAsFixed(2);
    });
  }

  double get _enteredTotalBudget =>
      double.tryParse(_totalBudgetController.text.trim()) ?? 0.0;

  Map<String, double> _enteredCategoryBudgets() {
    final budgets = <String, double>{};
    for (final entry in _categoryControllers.entries) {
      budgets[entry.key] = double.tryParse(entry.value.text.trim()) ?? 0.0;
    }
    return budgets;
  }

  /// Over-allocating is a warning, never a wall: the user is told by how much
  /// and decides. Blocking the save is what made an existing budget feel
  /// impossible to edit downwards.
  Future<bool> _confirmOverAllocation(
    double totalBudget,
    double totalAllocated,
    String currencySymbol,
  ) async {
    String money(double value) => UtilityFunction.formatMoney(
          value,
          symbol: currencySymbol,
          showDecimals: true,
        );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appSurface,
        title: const Text('Categories exceed your budget'),
        content: Text(
          'Category budgets add up to ${money(totalAllocated)}, which is '
          '${money(totalAllocated - totalBudget)} more than your '
          '${money(totalBudget)} budget for $_monthLabel.\n\n'
          'Save anyway, or go back and adjust?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save anyway'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _saveBudgets() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();

    final budgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);
    final currencySymbol =
        Provider.of<SettingsProvider>(context, listen: false).currencySymbol;

    final categoryBudgets = _enteredCategoryBudgets();
    final totalAllocated =
        categoryBudgets.values.fold<double>(0, (sum, value) => sum + value);
    var totalBudget = _enteredTotalBudget;

    // Budgeting by category alone is valid — the month's budget is then just
    // what the categories add up to.
    final derivedFromCategories = totalBudget <= 0 && totalAllocated > 0;
    if (derivedFromCategories) {
      totalBudget = totalAllocated;
      _totalBudgetController.text = totalBudget.toStringAsFixed(2);
    }

    if (totalBudget <= 0 && totalAllocated <= 0 && !_monthHasSavedBudget) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enter a budget for $_monthLabel first'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (totalAllocated - totalBudget > _overAllocationTolerance) {
      final proceed = await _confirmOverAllocation(
        totalBudget,
        totalAllocated,
        currencySymbol,
      );
      if (!proceed || !mounted) return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await budgetProvider.saveMonthBudget(
        month: _monthKey,
        totalBudget: totalBudget,
        categoryBudgets: categoryBudgets,
        scope: _scope,
      );

      if (!mounted) return;
      setState(() {
        _monthHasSavedBudget = totalBudget > 0 || totalAllocated > 0;
        _seededFromLabel = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            derivedFromCategories
                ? '$_monthLabel budget saved from your category totals'
                : '$_monthLabel budget saved',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
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

  /// Pulls the last budgeted month's figures into the form. Nothing is written
  /// until the user saves, so they can adjust first.
  Future<void> _copyFromPreviousMonth() async {
    final budgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);
    final previous = await budgetProvider.previousMonthBudget(_monthKey);

    if (!mounted) return;

    if (previous == null || previous.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No earlier month has a budget to copy'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _applySnapshot(previous);
      _seededFromLabel = previous.label;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Loaded ${previous.label}'s budget — save to apply"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _clearMonthBudget() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Text('Clear $_monthLabel budget?'),
        content: Text(
          'This removes the budget for $_monthLabel only. Your transactions '
          'and other months are untouched.',
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
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await Provider.of<MonthlyBudgetProvider>(context, listen: false)
          .clearMonth(_monthKey);

      if (!mounted) return;
      setState(() {
        _totalBudgetController.clear();
        for (final controller in _categoryControllers.values) {
          controller.clear();
        }
        _monthHasSavedBudget = false;
        _seededFromLabel = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_monthLabel budget cleared'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not clear budget: $e'),
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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appSurface,
        title: const Text('Copy Budget to Next Month'),
        content: Text(
          'The figures shown for $_monthLabel will be copied to $nextMonthName. Any existing budget for $nextMonthName will be replaced.\n\nDo you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Copy'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      final budgetProvider =
          Provider.of<MonthlyBudgetProvider>(context, listen: false);

      // Copy what's on screen, not what was last saved — otherwise an edit
      // made just before tapping Copy silently doesn't travel.
      final categoryBudgets = _enteredCategoryBudgets();
      final totalAllocated =
          categoryBudgets.values.fold<double>(0, (sum, value) => sum + value);
      final totalBudget =
          _enteredTotalBudget > 0 ? _enteredTotalBudget : totalAllocated;

      await budgetProvider.saveMonthBudget(
        month: _monthKey,
        totalBudget: totalBudget,
        categoryBudgets: categoryBudgets,
        scope: _scope,
      );
      await budgetProvider.copyBudget(
        fromMonth: _monthKey,
        toMonth: BudgetPeriod.keyFor(nextMonth),
      );

      if (!mounted) return;
      setState(() {
        _monthHasSavedBudget = totalBudget > 0 || totalAllocated > 0;
        _seededFromLabel = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Budget copied to $nextMonthName'),
          backgroundColor: AppColors.positive,
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  void _selectMonth(DateTime month) {
    final target = DateTime(month.year, month.month);
    if (target.year == _selectedMonth.year &&
        target.month == _selectedMonth.month) {
      return;
    }

    setState(() {
      _selectedMonth = target;
      for (final controller in _categoryControllers.values) {
        controller.dispose();
      }
      _categoryControllers.clear();
      _totalBudgetController.clear();
      _seededFromLabel = null;
      _monthHasSavedBudget = false;
      _isLoading = true;
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
                    // Sizes to its 12 months instead of being clipped to a
                    // fixed height — the old 240px box hid Jul–Dec entirely,
                    // making later months impossible to select.
                    Flexible(
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.6,
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
        // Short, so it doesn't truncate next to the month chip and menu.
        title: const Text('Budget'),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _showMonthPicker(context),
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text(DateFormat('MMM yyyy').format(_selectedMonth)),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Month options',
            color: context.appSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              switch (value) {
                case 'copyPrevious':
                  _copyFromPreviousMonth();
                  break;
                case 'copyNext':
                  _copyToNextMonth();
                  break;
                case 'clear':
                  _clearMonthBudget();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copyPrevious',
                child: Row(
                  children: [
                    Icon(Icons.history, size: 18),
                    SizedBox(width: 10),
                    Text('Copy from last month'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copyNext',
                child: Row(
                  children: [
                    Icon(Icons.copy_all_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Copy to next month'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: AppColors.negative),
                    const SizedBox(width: 10),
                    Text(
                      'Clear this month',
                      style: TextStyle(color: AppColors.negative),
                    ),
                  ],
                ),
              ),
            ],
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
            // Compared with a tolerance: a split of an indivisible total can
            // land a fraction of a cent over, which must not read as "over
            // budget by 0.00".
            final isOverAllocated =
                totalAllocated - totalBudget > _overAllocationTolerance;
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
                                  _monthLabel,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
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
                                          // Deliberately no "required" rule:
                                          // an empty field means "budget by
                                          // category", and blocking here is
                                          // what made a set budget feel
                                          // uneditable.
                                          validator: (value) {
                                            final text = value?.trim() ?? '';
                                            if (text.isEmpty) return null;

                                            final amount =
                                                double.tryParse(text);
                                            if (amount == null) {
                                              return 'Enter a number';
                                            }
                                            if (amount < 0) {
                                              return "Can't be negative";
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
                                      isOverAllocated
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
                                        isOverAllocated
                                            ? 'Over by'
                                            : 'Unallocated',
                                        isOverAllocated
                                            ? remainingBudget.abs()
                                            : (remainingBudget < 0
                                                ? 0
                                                : remainingBudget),
                                        currencySymbol,
                                        isWarning: isOverAllocated,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacing16),
                          _buildScopeSelector(context, categories.length),
                          const SizedBox(height: AppDimensions.spacing16),
                          _buildMonthStatusBanner(
                            context,
                            totalBudget: totalBudget,
                            totalAllocated: totalAllocated,
                            currencySymbol: currencySymbol,
                          ),
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
                                'Category budgets',
                                style: AppTextStyles.sectionTitle.copyWith(
                                  color: context.textSecondary,
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

  /// Chooses what the monthly figure is measured against. This is the
  /// difference between "I may spend $4,800 in total" and an envelope budget
  /// like "$1,000 for food and groceries", where rent must not eat the budget.
  Widget _buildScopeSelector(BuildContext context, int categoryCount) {
    final budgetedCount = _categoryControllers.entries
        .where((entry) => (double.tryParse(entry.value.text.trim()) ?? 0) > 0)
        .length;
    final currencySymbol =
        Provider.of<SettingsProvider>(context, listen: false).currencySymbol;

    Widget option(BudgetScope scope) {
      final isSelected = _scope == scope;
      return Expanded(
        child: InkWell(
          onTap: () => _selectScope(scope),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing12,
              vertical: AppDimensions.spacing12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.appAccent.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(
                color: isSelected
                    ? context.appAccent
                    : AppColors.divider.withValues(alpha: 0.4),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: isSelected ? context.appAccent : context.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scope.label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? context.appAccent
                          : context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isCategoryScoped = _scope == BudgetScope.budgetedCategories;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What counts toward this budget',
            style: AppTextStyles.sectionTitle.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Row(
            children: [
              option(BudgetScope.allExpenses),
              const SizedBox(width: AppDimensions.spacing8),
              option(BudgetScope.budgetedCategories),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            _scope.description,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.textSecondary,
              height: 1.35,
            ),
          ),
          // A category-scoped budget with nothing budgeted would measure
          // against no spending at all, so say so before it's saved.
          if (isCategoryScoped) ...[
            const SizedBox(height: AppDimensions.spacing8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  budgetedCount > 0
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  size: 16,
                  color: budgetedCount > 0
                      ? AppColors.positive
                      : AppColors.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    budgetedCount > 0
                        ? 'Counting $budgetedCount of $categoryCount categories.'
                        : 'Give at least one category an amount below, or this budget has nothing to measure.',
                    style: AppTextStyles.caption.copyWith(
                      color: budgetedCount > 0
                          ? context.textSecondary
                          : AppColors.warning,
                      fontSize: 11,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            // Stays available after the switch, since editing a category
            // amount pulls the two figures apart again.
            if (budgetedCount > 0 && _totalDiffersFromAllocated) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _offerToMatchTotalToCategories(
                  _enteredTotalBudget,
                  _enteredAllocated,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.sync_alt, size: 15, color: context.appAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Categories total ${UtilityFunction.formatMoney(_enteredAllocated, symbol: currencySymbol, showDecimals: true)} — tap to match the monthly budget',
                          style: AppTextStyles.caption.copyWith(
                            color: context.appAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// One line above the editor telling the user where this month's numbers
  /// came from and whether the split still fits — shown while they type, so
  /// nothing is a surprise at save time.
  Widget _buildMonthStatusBanner(
    BuildContext context, {
    required double totalBudget,
    required double totalAllocated,
    required String currencySymbol,
  }) {
    if (_isLoading) return const SizedBox.shrink();

    String money(double value) => UtilityFunction.formatMoney(
          value,
          symbol: currencySymbol,
          showDecimals: true,
        );

    final overBy = totalAllocated - totalBudget;
    final isOverAllocated =
        totalBudget > 0 && overBy > _overAllocationTolerance;

    late final IconData icon;
    late final Color color;
    late final String message;

    if (isOverAllocated) {
      icon = Icons.warning_amber_rounded;
      color = AppColors.warning;
      message =
          'Categories are ${money(overBy)} over your $_monthLabel budget. '
          'You can still save — the overage is just flagged.';
    } else if (_seededFromLabel != null) {
      icon = Icons.history;
      color = context.appAccent;
      message = 'No budget saved for $_monthLabel yet. Prefilled from '
          '$_seededFromLabel — adjust and save to track this month.';
    } else if (!_monthHasSavedBudget) {
      icon = Icons.flag_outlined;
      color = context.appAccent;
      message = 'Set a budget for $_monthLabel to start tracking it.';
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spacing12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppDimensions.spacing8),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
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
    String label,
    double amount,
    String currencySymbol, {
    bool isWarning = false,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isWarning) ...[
              const Icon(Icons.warning_amber_rounded,
                  size: 13, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
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
