import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../utilities/constants.dart';

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
    _categoryControllers.values.forEach((controller) => controller.dispose());
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
      _categoryControllers.forEach((categoryName, controller) {
        final budget = double.tryParse(controller.text) ?? 0;
        totalAllocated += budget;
      });

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
      _categoryControllers.forEach((categoryName, controller) {
        final budget = double.tryParse(controller.text) ?? 0;
        budgetProvider.setBudget(categoryName, currentMonth, budget);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Budgets saved successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Manage Budget', style: AppTextStyles.h3),
        centerTitle: true,
        elevation: 0,
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
                          // Total Budget Card
                          Container(
                            padding:
                                const EdgeInsets.all(AppDimensions.spacing20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusLarge),
                              boxShadow: AppShadows.card,
                              border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Monthly Budget Cap',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppDimensions.spacing12),
                                TextFormField(
                                  controller: _totalBudgetController,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.h1.copyWith(
                                    color: AppColors.primary,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '0',
                                    border: InputBorder.none,
                                    prefixIcon: Icon(
                                      Icons.attach_money,
                                      color: AppColors.primary,
                                    ),
                                    prefixIconConstraints: BoxConstraints(
                                        minWidth: 0, minHeight: 0),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppDimensions.spacing16),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: AppColors.surfaceLight,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progress > 1.0
                                          ? AppColors.negative
                                          : AppColors.secondary,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: AppDimensions.spacing16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildSummaryItem(
                                      'Allocated',
                                      totalAllocated,
                                      AppColors.textSecondary,
                                    ),
                                    Container(
                                      height: 30,
                                      width: 1,
                                      color: AppColors.divider,
                                    ),
                                    _buildSummaryItem(
                                      'Remaining',
                                      remainingBudget,
                                      remainingBudget < 0
                                          ? AppColors.negative
                                          : AppColors.positive,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacing24),
                          Text(
                            'CATEGORY ALLOCATION',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacing12),

                          // Category List
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: categories.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: AppDimensions.spacing12),
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

                              return Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusMedium),
                                  border: budget > 0
                                      ? Border.all(
                                          color: progressColor.withValues(
                                              alpha: 0.2),
                                          width: 1,
                                        )
                                      : null,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.spacing16,
                                  vertical: AppDimensions.spacing12,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          padding: const EdgeInsets.all(
                                              AppDimensions.spacing8),
                                          decoration: BoxDecoration(
                                            color: AppColors.background,
                                            borderRadius: BorderRadius.circular(
                                                AppDimensions.radiusSmall),
                                          ),
                                          child: Image.asset(category.icon),
                                        ),
                                        const SizedBox(
                                            width: AppDimensions.spacing16),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            category.name,
                                            style: AppTextStyles.bodyLarge
                                                .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                            width: AppDimensions.spacing12),
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: _categoryControllers[
                                                category.name],
                                            textAlign: TextAlign.end,
                                            style:
                                                AppTextStyles.amount.copyWith(
                                              color: AppColors.textPrimary,
                                              fontSize: 16,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: '0',
                                              prefixText: '\$ ',
                                              prefixStyle: TextStyle(
                                                  color:
                                                      AppColors.textSecondary),
                                              isDense: true,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide.none,
                                              ),
                                              filled: true,
                                              fillColor: AppColors.background,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                            ),
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (budget > 0) ...[
                                      const SizedBox(
                                          height: AppDimensions.spacing12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: percentSpent.clamp(0.0, 1.0),
                                          backgroundColor: AppColors.background,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  progressColor),
                                          minHeight: 6,
                                        ),
                                      ),
                                      const SizedBox(
                                          height: AppDimensions.spacing8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Spent: \$${spent.toStringAsFixed(2)}',
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              color: progressColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '${(percentSpent * 100).toStringAsFixed(0)}%',
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.spacing16),
        child: SizedBox(
          width: MediaQuery.of(context).size.width - 32, // More compact
          height: AppDimensions.buttonHeight,
          child: ElevatedButton(
            onPressed: _saveBudgets,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4, // Reduced elevation
              shadowColor: AppColors.primary.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
            ),
            child: const Text(
              'Save Changes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: AppTextStyles.bodyLarge.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
