import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../models/transaction.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';
import '../screens/upcoming_payments_screen.dart';

class UpcomingPaymentsWidget extends StatelessWidget {
  const UpcomingPaymentsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<TransactionProvider, CategoryProvider, SettingsProvider>(
      builder: (context, transactionProvider, categoryProvider,
          settingsProvider, child) {
        final upcomingList = transactionProvider.upcomingTransactions;
        final currencySymbol = settingsProvider.currencySymbol;

        if (upcomingList.isEmpty) {
          return const SizedBox.shrink();
        }

        // Use provider's computed total (from all transactions, not just 5)
        final totalAmount = transactionProvider.totalUpcomingAmount;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).pushNamed(UpcomingPaymentsScreen.routeName);
          },
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            decoration: BoxDecoration(
              color: context.appSurfaceLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'UPCOMING PAYMENTS',
                          style: AppTextStyles.caption.copyWith(
                            color: context.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: context.textSecondary,
                        ),
                      ],
                    ),
                    // Total amount
                    Text(
                      UtilityFunction.addCommaWithSign(
                        totalAmount,
                        currencySymbol: currencySymbol,
                      ),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.negative,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacing16),

                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: upcomingList.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final transaction = upcomingList[index];
                      final category =
                          categoryProvider.categoryMap[transaction.categoryId];

                      return _buildPaymentCard(context, transaction,
                          category?.icon, category?.name, currencySymbol);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentCard(BuildContext context, Transaction transaction,
      String? iconPath, String? categoryName, String currencySymbol) {
    // Date Logic
    String dateString;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDate = DateTime(
        transaction.date.year, transaction.date.month, transaction.date.day);

    final bool isToday = txDate.isAtSameMomentAs(today);

    if (isToday) {
      dateString = 'Today';
    } else if (txDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      dateString = 'Tomorrow';
    } else {
      dateString = DateFormat('MMM d').format(transaction.date);
    }

    final daysUntil = txDate.difference(today).inDays;

    // Status Logic
    // If it's today, we show "Today" in urgency color, but NO badge needed (redundant).
    // If it's soon (1-3 days), we might show a badge.

    final bool showDueBadge = !isToday && daysUntil <= 3;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurface, // Use standard surface color for cards
        borderRadius: BorderRadius.circular(16),
        // No border for inner cards to match 'QuickStats' style
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: iconPath != null
                    ? Image.asset(
                        iconPath,
                        width: 20,
                        height: 20,
                        errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.category,
                            size: 20,
                            color: context.textSecondary),
                      )
                    : Icon(Icons.category_outlined,
                        size: 20, color: context.textSecondary),
              ),
              if (showDueBadge)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.negative.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${daysUntil}d left',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.negative,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            transaction.title.isEmpty
                ? categoryName ?? 'Unknown Category'
                : transaction.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            UtilityFunction.addCommaWithSign(
              transaction.amount,
              currencySymbol: currencySymbol,
            ),
            style: AppTextStyles.amount.copyWith(
              fontSize: 16,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateString,
            style: AppTextStyles.caption.copyWith(
              color: isToday ? AppColors.negative : context.textSecondary,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
