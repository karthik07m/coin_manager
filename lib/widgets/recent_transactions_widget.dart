import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../utilities/constants.dart';

class RecentTransactionsWidget extends StatelessWidget {
  const RecentTransactionsWidget({super.key});

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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT TRANSACTIONS',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to transactions tab
                    DefaultTabController.of(context).animateTo(1);
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
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: ListView.separated(
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
                        color: AppColors.background,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSmall),
                      ),
                      child: Image.asset(category.icon),
                    ),
                    title: Text(
                      transaction.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      DateFormat('MMM dd, yyyy').format(transaction.date),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: Text(
                      '${transaction.isExpense ? '-' : '+'} \$${transaction.amount.toStringAsFixed(2)}',
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
            ),
          ],
        );
      },
    );
  }
}
