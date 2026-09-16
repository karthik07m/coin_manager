import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';
import '../screens/all_transactions_screen.dart';
import '../screens/transaction_form.dart';
import 'tappable.dart';

class RecentTransactionsWidget extends StatelessWidget {
  final Function(int)? onTabSelected;

  const RecentTransactionsWidget({super.key, this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    // Use Consumer only for TransactionProvider — the only data that changes
    // frequently. Categories and settings are accessed via Provider.of(listen: false)
    // for one-time reads, avoiding rebuilds on unrelated provider changes.
    return Consumer<TransactionProvider>(
      builder: (context, transactionProvider, child) {
        final categoryProvider =
            Provider.of<CategoryProvider>(context, listen: false);
        final currencySymbol =
            Provider.of<SettingsProvider>(context, listen: false)
                .currencySymbol;
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
                // Same treatment as the "Accounts" header above it, so the
                // home screen has one section-title style, not two.
                Text(
                  'Recent transactions',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to All Transactions screen
                    Navigator.of(context)
                        .pushNamed(AllTransactionsScreen.routeName);
                  },
                  child: Text(
                    'See All',
                    style: AppTextStyles.caption.copyWith(
                      color: context.appAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing8),
            ListView.separated(
              padding: EdgeInsets.zero,
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

                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 200 + (index * 50)),
                  curve: Curves.fastOutSlowIn,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Tappable(
                    color: context.appSurface,
                    borderRadius: AppDimensions.radiusMedium,
                    pressedScale: 0.98,
                    openPage: TransactionForm(transaction: transaction),
                    child: ListTile(
                      // Compact toward the ~64dp rows on the transaction
                      // screens. Note: the gap between the section header and
                      // the first row survives this — its source is not the
                      // tile's padding and is still unidentified.
                      minVerticalPadding: 0,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacing12,
                        vertical: AppDimensions.spacing4,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          // Category tint, matching the transaction rows:
                          // the amount colour already carries the sign.
                          color: transaction.isTransfer
                              ? context.appAccent.withValues(alpha: 0.1)
                              : category.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: transaction.isTransfer
                            ? Icon(
                                Icons.swap_horiz_rounded,
                                size: 24,
                                color: context.appAccent,
                              )
                            : Image.asset(
                                category.icon,
                                width: 24,
                                height: 24,
                              ),
                      ),
                      title: Text(
                        transaction.isTransfer
                            ? 'Transfer'
                            : (transaction.title.isEmpty
                                ? category.name
                                : transaction.title),
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
                        transaction.isTransfer
                            ? UtilityFunction.addCommaWithSign(
                                transaction.amount,
                                currencySymbol: currencySymbol)
                            : '${transaction.isExpense ? '-' : '+'}${UtilityFunction.addCommaWithSign(transaction.amount.abs(), currencySymbol: currencySymbol)}',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: transaction.isTransfer
                              ? context.textSecondary
                              : (transaction.isExpense
                                  ? AppColors.negative
                                  : AppColors.positive),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
