import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';

class RecentTransactionsWidget extends StatelessWidget {
  final Function(int)? onTabSelected;

  const RecentTransactionsWidget({super.key, this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionProvider, CategoryProvider>(
      builder: (context, transactionProvider, categoryProvider, child) {
        final allTransactions = transactionProvider.transactions;

        // Get last 5 transactions
        final recentTransactions = allTransactions.take(5).toList();

        if (recentTransactions.isEmpty) {
          return const SizedBox.shrink();
        }

        // Check if categories are loaded
        if (categoryProvider.categories.isEmpty) {
          return const Center(
            child: Text('Loading categories...'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT TRANSACTIONS',
                  style: AppTextStyles.caption.copyWith(
                    color: context.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to transactions tab
                    onTabSelected?.call(1);
                  },
                  child: Text(
                    'See All',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentTransactions.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: AppColors.divider,
                indent: 60,
              ),
              itemBuilder: (context, index) {
                final transaction = recentTransactions[index];

                // Safely find category
                final category = categoryProvider.categories.firstWhere(
                  (cat) => cat.id == transaction.categoryId,
                  orElse: () => categoryProvider.categories.first,
                );

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing12,
                    vertical: AppDimensions.spacing4,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (transaction.isExpense
                              ? AppColors.negative
                              : AppColors.positive)
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      category.icon,
                      width: 24,
                      height: 24,
                    ),
                  ),
                  title: Text(
                    transaction.title.isEmpty
                        ? category.name
                        : transaction.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy').format(transaction.date),
                    style: AppTextStyles.caption.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  trailing: Text(
                    '${transaction.isExpense ? '-' : '+'}${UtilityFunction.addCommaWithSign(transaction.amount).substring(1)}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: transaction.isExpense
                          ? AppColors.negative
                          : AppColors.positive,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
