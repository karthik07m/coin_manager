import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../utilities/budget_scope_summary.dart';
import '../screens/manage_budget.dart';
import '../screens/all_transactions_screen.dart';
import 'package:intl/intl.dart';
import 'tappable.dart';
import '../utilities/page_transitions.dart';

class BudgetOverviewWidget extends StatelessWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime>? onMonthChanged;

  const BudgetOverviewWidget({
    super.key,
    required this.selectedMonth,
    this.onMonthChanged,
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

        // An overall budget with no category split is still a budget — the
        // empty state only belongs here when the month has nothing at all.
        final overallBudget = budgetProvider.getTotalBudget(currentMonth);

        if (categoriesWithBudgets.isEmpty && overallBudget <= 0) {
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
              border: context.cardBorder,
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
                  'No budget for ${DateFormat('MMMM').format(selectedMonth)}',
                  style: AppTextStyles.h2.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
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

        // Per-category budgets drive the breakdown below and the on-track
        // count, but the summary tracks the OVERALL budget so it matches the
        // Monthly Budget card (one honest "am I over?" number).
        double sumCategoryBudgets = 0;
        int onTrackCount = 0;
        for (var category in categoriesWithBudgets) {
          final budget = budgetProvider.getBudget(category.name, currentMonth);
          final spent = transactionProvider.getCategorySpending(
            category.id!,
            startDate,
            endDate,
          );
          sumCategoryBudgets += budget;

          final percentSpent = budget > 0 ? (spent / budget) : 0.0;
          if (percentSpent < 0.8) {
            onTrackCount++;
          }
        }

        // Overall budget = the month's total budget (fall back to the sum of
        // category budgets if no total is set). Spent is measured on the same
        // basis as the top card — all expenses, or only budgeted categories.
        final totalBudget =
            overallBudget > 0 ? overallBudget : sumCategoryBudgets;
        final summary = BudgetScopeSummary.compute(
          monthExpenses: transactionProvider.transactions
              .where((t) =>
                  t.isExpense &&
                  !t.isTransfer &&
                  !t.date.isBefore(startDate) &&
                  !t.date.isAfter(endDate))
              .toList(),
          amountOf: transactionProvider.baseAmount,
          scope: budgetProvider.getScope(currentMonth),
          budgetedCategoryIds: BudgetScopeSummary.budgetedCategoryIds(
            categories: expenseCategories,
            budgetFor: (name) => budgetProvider.getBudget(name, currentMonth),
          ),
        );
        final totalSpent = summary.countedSpent;

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
                // Neutral like the other cards; the pill and bar carry status.
                color: context.appSurface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                border: context.cardBorder,
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
                            summary.isCategoryScoped
                                ? 'Category budget'
                                : 'Total budget',
                            style: AppTextStyles.caption.copyWith(
                              color: context.textSecondary,
                              fontSize: 11,
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
                          // Past 999% the exact figure is noise, not news.
                          totalPercent >= 10
                              ? '999%+'
                              : '${(totalPercent * 100).toStringAsFixed(0)}%',
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
                        // When the budget only covers some categories, what
                        // it ignores matters more than how many it counts.
                        child: summary.isCategoryScoped
                            ? _buildStatBox(
                                context,
                                icon: Icons.remove_circle_outline,
                                label: 'Unbudgeted',
                                value: UtilityFunction.formatMoney(
                                    summary.unbudgetedSpent,
                                    symbol: currencySymbol),
                                color: context.textSecondary,
                              )
                            : _buildStatBox(
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

            // Editing lives beside the month selector; this section explains
            // the breakdown instead of duplicating the same editor action.
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Category breakdown',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                Text(
                  '$daysRemaining days left',
                  style: AppTextStyles.caption.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing12),

            // A total with no category split still tracks fine, but the
            // breakdown is where overspending gets caught early.
            if (categoriesWithBudgets.isEmpty) _buildSplitPrompt(context),

            // Category cards
            ...categoriesWithBudgets.map((category) {
              final budget =
                  budgetProvider.getBudget(category.name, currentMonth);
              final spent = transactionProvider.getCategorySpending(
                category.id!,
                startDate,
                endDate,
              );
              final txCount = transactionProvider.getCategoryTransactionCount(
                category.id!,
                startDate,
                endDate,
              );

              return BudgetProgressCard(
                categoryName: category.name,
                categoryIcon: category.icon,
                budgetAmount: budget,
                spentAmount: spent,
                transactionCount: txCount,
                daysRemaining: daysRemaining,
                daysElapsed: daysElapsed,
                periodDays: periodDays,
                currencySymbol: currencySymbol,
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransitions.fadeUp(
                      AllTransactionsScreen(
                        initialStartDate: startDate,
                        initialEndDate: endDate,
                        initialCategoryId: category.id,
                        hideFiltersInitially: true,
                      ),
                    ),
                  );
                },
              );
            }),

            _BudgetPeriodHistoryStrip(
              selectedMonth: selectedMonth,
              onMonthChanged: onMonthChanged,
              budgetRevision: budgetProvider.revision,
            ),
          ],
        );
      },
    );
  }

  /// The whole card is the tap target — a trailing button here would sit
  /// under the floating action button.
  Widget _buildSplitPrompt(BuildContext context) {
    return Tappable(
      color: context.appSurface,
      onTap: () {
        Navigator.pushNamed(
          context,
          '/manageBudget',
          arguments: ManageBudgetArgs(
            initialMonth: selectedMonth,
            autoAllocate: true,
          ),
        );
      },
      borderRadius: AppDimensions.radiusMedium,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: context.appAccent.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.pie_chart_outline, color: context.appAccent, size: 22),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Split it across categories',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Per-category budgets catch overspending early. Tap to set them up.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
  final ValueChanged<DateTime>? onMonthChanged;

  /// Changes whenever a budget is written, so the cached history reloads
  /// instead of showing what was true before the edit.
  final int budgetRevision;

  const _BudgetPeriodHistoryStrip({
    required this.selectedMonth,
    required this.budgetRevision,
    this.onMonthChanged,
  });

  @override
  State<_BudgetPeriodHistoryStrip> createState() =>
      _BudgetPeriodHistoryStripState();
}

class _BudgetPeriodHistoryStripState extends State<_BudgetPeriodHistoryStrip> {
  static const int _monthsShown = 6;

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
        oldWidget.selectedMonth.month != widget.selectedMonth.month ||
        oldWidget.budgetRevision != widget.budgetRevision) {
      _historyFuture = _loadHistory();
    }
  }

  Future<List<_BudgetHistoryItem>> _loadHistory() async {
    final budgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);

    final months = List.generate(
      _monthsShown,
      (index) => DateTime(
        widget.selectedMonth.year,
        widget.selectedMonth.month - (_monthsShown - 1 - index),
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

        // Newest first, so the month you're looking at is always the card you
        // land on; older months scroll off to the right.
        final orderedItems = items.reversed.toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget by month',
              style: AppTextStyles.sectionTitle.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            SizedBox(
              // Grows with the user's font size — a fixed height clips the
              // amount off these cards at large accessibility text scales.
              height: 138 *
                  MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: orderedItems.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppDimensions.spacing12),
                itemBuilder: (context, index) {
                  final item = orderedItems[index];
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

    return GestureDetector(
      onTap: () {
        if (widget.onMonthChanged != null) {
          HapticFeedback.selectionClick();
          widget.onMonthChanged!(item.month);
        }
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(AppDimensions.spacing12),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? context.appAccent
                : context.appBorder.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  // Six months can straddle a year boundary — say which year
                  // when it isn't the one being viewed.
                  item.month.year == widget.selectedMonth.year
                      ? DateFormat('MMM').format(item.month)
                      : DateFormat("MMM ''yy").format(item.month),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: AppColors.divider.withValues(alpha: 0.25),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
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
      ),
    );
  }
}
