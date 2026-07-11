import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/budget_progress_card.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';
import '../utilities/budget_period.dart';
import '../screens/manage_budget.dart';
import 'package:intl/intl.dart';

class BudgetOverviewWidget extends StatelessWidget {
  final DateTime selectedMonth;

  const BudgetOverviewWidget({
    super.key,
    required this.selectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    final startDate = BudgetPeriod.startOfMonth(selectedMonth);
    final endDate = BudgetPeriod.endOfMonth(selectedMonth);
    final currentMonth = BudgetPeriod.keyFor(selectedMonth);
    final daysRemaining = BudgetPeriod.daysRemaining(selectedMonth);
    final periodDays = BudgetPeriod.daysInMonth(selectedMonth);
    final daysElapsed = BudgetPeriod.daysElapsed(selectedMonth);

    return Consumer3<CategoryProvider, MonthlyBudgetProvider,
        TransactionProvider>(
      builder: (context, categoryProvider, budgetProvider, transactionProvider,
          child) {
        final currencySymbol =
            Provider.of<SettingsProvider>(context).currencySymbol;
        final expenseCategories =
            categoryProvider.categories.where((cat) => cat.isExpense).toList();

        // Filter categories that have budgets set
        final categoriesWithBudgets = expenseCategories.where((category) {
          final budget = budgetProvider.getBudget(category.name, currentMonth);
          return budget > 0;
        }).toList();

        if (categoriesWithBudgets.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppDimensions.spacing32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.appAccent.withValues(alpha: 0.05),
                  AppColors.secondary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(
                color: context.appAccent.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: context.appAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 40,
                    color: context.appAccent,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing20),
                Text(
                  'No budgets set',
                  style: AppTextStyles.h2.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing8),
                Text(
                  'Create smart category budgets from your\nincome and monthly budget, then adjust if needed.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacing20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/manageBudget',
                      arguments: ManageBudgetArgs(
                        initialMonth: selectedMonth,
                        autoAllocate: true,
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: const Text('Set Budgets'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Calculate summary statistics
        double totalBudget = 0;
        double totalSpent = 0;
        int onTrackCount = 0;

        for (var category in categoriesWithBudgets) {
          final budget = budgetProvider.getBudget(category.name, currentMonth);
          final spent = transactionProvider.getCategorySpending(
            category.id!,
            startDate,
            endDate,
          );
          totalBudget += budget;
          totalSpent += spent;

          final percentSpent = budget > 0 ? (spent / budget) : 0.0;
          if (percentSpent < 0.8) {
            onTrackCount++;
          }
        }

        final totalPercent = totalBudget > 0 ? (totalSpent / totalBudget) : 0.0;

        // Determine overall status color
        Color statusColor;
        if (totalPercent >= 1.0) {
          statusColor = AppColors.negative;
        } else if (totalPercent >= 0.8) {
          statusColor = AppColors.warning;
        } else {
          statusColor = AppColors.positive;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    statusColor.withValues(alpha: 0.1),
                    statusColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL BUDGET',
                            style: AppTextStyles.caption.copyWith(
                              color: context.textSecondary,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            UtilityFunction.formatMoney(totalBudget,
                                symbol: currencySymbol),
                            style: AppTextStyles.h2.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${(totalPercent * 100).toStringAsFixed(0)}%',
                          style: AppTextStyles.amount.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacing16),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(
                        begin: 0,
                        end: totalPercent.clamp(0.0, 1.0),
                      ),
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        minHeight: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing16),

                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBox(
                          context,
                          icon: Icons.shopping_bag,
                          label: 'Spent',
                          value: UtilityFunction.formatMoney(totalSpent,
                              symbol: currencySymbol),
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacing12),
                      Expanded(
                        child: _buildStatBox(
                          context,
                          icon: Icons.calendar_today,
                          label: 'Categories',
                          value: '${categoriesWithBudgets.length}',
                          color: context.appAccent,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacing12),
                      Expanded(
                        child: _buildStatBox(
                          context,
                          icon: Icons.check_circle,
                          label: 'On Track',
                          value: '$onTrackCount',
                          color: AppColors.positive,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.spacing24),

            // Section header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CATEGORY BREAKDOWN',
                  style: AppTextStyles.caption.copyWith(
                    color: context.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '$daysRemaining days left',
                      style: AppTextStyles.caption.copyWith(
                        color: context.appAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/manageBudget',
                          arguments: ManageBudgetArgs(
                            initialMonth: selectedMonth,
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Manage'),
                      style: TextButton.styleFrom(
                        foregroundColor: context.appAccent,
                        minimumSize: const Size(44, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing12),

            // Category cards
            ...categoriesWithBudgets.map((category) {
              final budget =
                  budgetProvider.getBudget(category.name, currentMonth);
              final spent = transactionProvider.getCategorySpending(
                category.id!,
                startDate,
                endDate,
              );

              return BudgetProgressCard(
                categoryName: category.name,
                categoryIcon: category.icon,
                budgetAmount: budget,
                spentAmount: spent,
                daysRemaining: daysRemaining,
                daysElapsed: daysElapsed,
                periodDays: periodDays,
                currencySymbol: currencySymbol,
              );
            }),

            const SizedBox(height: AppDimensions.spacing24),

            _BudgetPeriodHistoryStrip(selectedMonth: selectedMonth),
          ],
        );
      },
    );
  }

  Widget _buildStatBox(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetHistoryItem {
  final DateTime month;
  final double budget;
  final double spent;

  const _BudgetHistoryItem({
    required this.month,
    required this.budget,
    required this.spent,
  });

  double get percent => budget > 0 ? spent / budget : 0.0;

  Color get statusColor {
    if (budget <= 0) return AppColors.accentBlue;
    if (percent >= 1.0) return AppColors.negative;
    if (percent >= 0.8) return AppColors.warning;
    return AppColors.positive;
  }
}

class _BudgetPeriodHistoryStrip extends StatefulWidget {
  final DateTime selectedMonth;

  const _BudgetPeriodHistoryStrip({required this.selectedMonth});

  @override
  State<_BudgetPeriodHistoryStrip> createState() =>
      _BudgetPeriodHistoryStripState();
}

class _BudgetPeriodHistoryStripState extends State<_BudgetPeriodHistoryStrip> {
  Future<List<_BudgetHistoryItem>>? _historyFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _historyFuture ??= _loadHistory();
  }

  @override
  void didUpdateWidget(covariant _BudgetPeriodHistoryStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth.year != widget.selectedMonth.year ||
        oldWidget.selectedMonth.month != widget.selectedMonth.month) {
      _historyFuture = _loadHistory();
    }
  }

  Future<List<_BudgetHistoryItem>> _loadHistory() async {
    final budgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);

    final months = List.generate(
      4,
      (index) => DateTime(
        widget.selectedMonth.year,
        widget.selectedMonth.month - (3 - index),
        1,
      ),
    );

    final history = <_BudgetHistoryItem>[];
    for (final month in months) {
      final startDate = BudgetPeriod.startOfMonth(month);
      final endDate = BudgetPeriod.endOfMonth(month);
      final budget = await budgetProvider.fetchTotalBudget(
        BudgetPeriod.keyFor(month),
      );
      final spent = await transactionProvider.getExpenseTotalForRange(
        startDate: startDate,
        endDate: endDate,
      );

      history.add(
        _BudgetHistoryItem(month: month, budget: budget, spent: spent),
      );
    }

    return history;
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).currencySymbol;

    return FutureBuilder<List<_BudgetHistoryItem>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <_BudgetHistoryItem>[];

        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        final hasAnyData =
            items.any((item) => item.budget > 0 || item.spent > 0);
        if (!hasAnyData) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PERIOD HISTORY',
              style: AppTextStyles.caption.copyWith(
                color: context.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            SizedBox(
              height: 138,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppDimensions.spacing12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected =
                      item.month.year == widget.selectedMonth.year &&
                          item.month.month == widget.selectedMonth.month;

                  return _buildHistoryCard(
                    context,
                    item: item,
                    isSelected: isSelected,
                    currencySymbol: currencySymbol,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryCard(
    BuildContext context, {
    required _BudgetHistoryItem item,
    required bool isSelected,
    required String currencySymbol,
  }) {
    final progress = item.percent.clamp(0.0, 1.0);
    final statusColor = item.statusColor;
    final statusText = item.budget <= 0
        ? 'No budget'
        : item.percent >= 1
            ? 'Over'
            : item.percent >= 0.8
                ? 'Close'
                : 'Good';

    return Container(
      width: 132,
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        border: Border.all(
          color: isSelected
              ? context.appAccent
              : statusColor.withValues(alpha: 0.25),
          width: isSelected ? 1.4 : 1,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM').format(item.month),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.divider.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            statusText,
            style: AppTextStyles.caption.copyWith(
              color: statusColor,
              fontSize: 10,
            ),
          ),
          const Spacer(),
          Text(
            UtilityFunction.formatMoney(item.spent, symbol: currencySymbol),
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'of ${UtilityFunction.formatMoney(item.budget, symbol: currencySymbol)}',
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
