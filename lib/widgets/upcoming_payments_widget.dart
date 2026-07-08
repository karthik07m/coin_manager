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

/// Upcoming bills, professional-app style: a vertical list sorted by due
/// date (icon · name · due date | amount), an honest 30-day total, and a
/// "view all" affordance. Red is reserved for bills due today.
class UpcomingPaymentsWidget extends StatelessWidget {
  static const int _maxRows = 3;
  static const int _windowDays = 30;

  const UpcomingPaymentsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<TransactionProvider, CategoryProvider, SettingsProvider>(
      builder: (context, transactionProvider, categoryProvider,
          settingsProvider, child) {
        final currencySymbol = settingsProvider.currencySymbol;

        // Scope to the next 30 days so the total means what it says.
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final windowEnd = today.add(const Duration(days: _windowDays));
        final upcoming = transactionProvider.allUpcomingTransactions
            .where((t) => !t.date.isAfter(windowEnd))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        if (upcoming.isEmpty) {
          return const SizedBox.shrink();
        }

        final totalAmount =
            upcoming.fold(0.0, (sum, t) => sum + t.amount);
        final visible = upcoming.take(_maxRows).toList();
        final hiddenCount = upcoming.length - visible.length;

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
                color: context.appAccent.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: title + honest windowed total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UPCOMING PAYMENTS',
                      style: AppTextStyles.caption.copyWith(
                        color: context.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          UtilityFunction.addCommaWithSign(
                            totalAmount,
                            currencySymbol: currencySymbol,
                          ),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'next $_windowDays days',
                          style: AppTextStyles.caption.copyWith(
                            color: context.textSecondary,
                            fontSize: 10,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacing12),

                // Vertical bill rows — nothing hidden off-screen
                ...List.generate(visible.length, (index) {
                  final transaction = visible[index];
                  final category =
                      categoryProvider.categoryMap[transaction.categoryId];
                  return Column(
                    children: [
                      if (index > 0)
                        Divider(
                          height: 1,
                          indent: 48,
                          color: AppColors.divider.withValues(alpha: 0.3),
                        ),
                      _buildPaymentRow(
                        context,
                        transaction,
                        category?.icon,
                        category?.name,
                        currencySymbol,
                        today,
                      ),
                    ],
                  );
                }),

                // View-all affordance when the list is truncated
                if (hiddenCount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View all ${upcoming.length} payments',
                        style: AppTextStyles.caption.copyWith(
                          color: context.appAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: context.appAccent,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentRow(
    BuildContext context,
    Transaction transaction,
    String? iconPath,
    String? categoryName,
    String currencySymbol,
    DateTime today,
  ) {
    final txDate = DateTime(
        transaction.date.year, transaction.date.month, transaction.date.day);
    final daysUntil = txDate.difference(today).inDays;

    String dueText;
    Color dueColor;
    if (daysUntil <= 0) {
      dueText = 'Due today';
      dueColor = AppColors.negative;
    } else if (daysUntil == 1) {
      dueText = 'Due tomorrow';
      dueColor = AppColors.warning;
    } else if (daysUntil <= 7) {
      dueText = 'In $daysUntil days · ${DateFormat('MMM d').format(txDate)}';
      dueColor = context.textSecondary;
    } else {
      dueText = DateFormat('EEE, MMM d').format(txDate);
      dueColor = context.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
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
                    errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.receipt_long,
                        size: 18,
                        color: context.textSecondary),
                  )
                : Icon(Icons.receipt_long,
                    size: 18, color: context.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title.isEmpty
                      ? categoryName ?? 'Payment'
                      : transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dueText,
                  style: AppTextStyles.caption.copyWith(
                    color: dueColor,
                    fontSize: 11,
                    fontWeight: daysUntil <= 1
                        ? FontWeight.w600
                        : FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            UtilityFunction.addCommaWithSign(
              transaction.amount,
              currencySymbol: currencySymbol,
            ),
            style: AppTextStyles.amount.copyWith(
              fontSize: 15,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
