import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../widgets/budget_progress_card.dart';
import '../utilities/constants.dart';

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
            padding: const EdgeInsets.all(AppDimensions.spacing20),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppDimensions.spacing12),
                Text(
                  'No budgets set',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing8),
                Text(
                  'Set category budgets to track your spending',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BUDGET PROGRESS',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '$daysRemaining days left',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing12),
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
            }).toList(),
          ],
        );
      },
    );
  }
}
