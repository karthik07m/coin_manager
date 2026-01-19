import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../widgets/budget_progress_card.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

class BudgetOverviewWidget extends StatelessWidget {
  const BudgetOverviewWidget({super.key});

  int _getDaysRemainingInMonth() {
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    return lastDayOfMonth.day - now.day + 1;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1);
    final endDate = DateTime(now.year, now.month + 1, 0);
    final currentMonth = now.month.toString();
    final daysRemaining = _getDaysRemainingInMonth();

    return Consumer3<CategoryProvider, MonthlyBudgetProvider,
        TransactionProvider>(
      builder: (context, categoryProvider, budgetProvider, transactionProvider,
          child) {
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
                  AppColors.primary.withValues(alpha: 0.05),
                  AppColors.secondary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 40,
                    color: AppColors.primary,
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
                  'Set category budgets to track your spending\nand achieve your financial goals',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacing20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/manageBudget');
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Set Budgets'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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
                            '\$${totalBudget.toStringAsFixed(2)}',
                            style: AppTextStyles.h2.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
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
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
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
                          value: '\$${totalSpent.toStringAsFixed(2)}',
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
                          color: AppColors.primary,
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
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/manageBudget');
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label:
                          const Text('Manage', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
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
              );
            }),
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
