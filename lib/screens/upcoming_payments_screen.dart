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

class UpcomingPaymentsScreen extends StatefulWidget {
  static const routeName = '/upcoming-payments';

  const UpcomingPaymentsScreen({super.key});

  @override
  State<UpcomingPaymentsScreen> createState() => _UpcomingPaymentsScreenState();
}

class _UpcomingPaymentsScreenState extends State<UpcomingPaymentsScreen> {
  @override
  void initState() {
    super.initState();
    // Load all upcoming transactions when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transactionProvider =
          Provider.of<TransactionProvider>(context, listen: false);
      transactionProvider.loadAllUpcomingTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('Upcoming Payments'),
        backgroundColor: context.appSurface,
        elevation: 0,
      ),
      body: Consumer3<TransactionProvider, CategoryProvider, SettingsProvider>(
        builder: (context, transactionProvider, categoryProvider,
            settingsProvider, child) {
          final upcomingList = transactionProvider.allUpcomingTransactions;
          final currencySymbol = settingsProvider.currencySymbol;

          if (upcomingList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: context.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Upcoming Payments',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add recurring transactions to see them here',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          // Calculate total
          final totalAmount = upcomingList.fold<double>(
            0.0,
            (sum, transaction) => sum + transaction.amount,
          );

          return Column(
            children: [
              // Total Summary Card
              Container(
                margin: const EdgeInsets.all(AppDimensions.spacing16),
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                decoration: BoxDecoration(
                  color: context.appSurfaceLight,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusLarge),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL UPCOMING',
                          style: AppTextStyles.caption.copyWith(
                            color: context.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          UtilityFunction.addCommaWithSign(
                            totalAmount,
                            currencySymbol: currencySymbol,
                          ),
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.negative,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.negative.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${upcomingList.length} Payment${upcomingList.length != 1 ? 's' : ''}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.negative,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // List of upcoming payments
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing16,
                  ),
                  itemCount: upcomingList.length,
                  itemBuilder: (context, index) {
                    final transaction = upcomingList[index];
                    final category =
                        categoryProvider.categoryMap[transaction.categoryId];

                    return _buildPaymentListItem(
                      context,
                      transaction,
                      category?.icon,
                      category?.name,
                      currencySymbol,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentListItem(
    BuildContext context,
    Transaction transaction,
    String? iconPath,
    String? categoryName,
    String currencySymbol,
  ) {
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
      dateString = DateFormat('MMM d, yyyy').format(transaction.date);
    }

    final daysUntil = txDate.difference(today).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing12),
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
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
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.category,
                      size: 24,
                      color: context.textSecondary,
                    ),
                  )
                : Icon(
                    Icons.category_outlined,
                    size: 24,
                    color: context.textSecondary,
                  ),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title.isEmpty
                      ? categoryName ?? 'Unknown Category'
                      : transaction.title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      dateString,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isToday
                            ? AppColors.negative
                            : context.textSecondary,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (daysUntil <= 3 && !isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.negative.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
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
                  ],
                ),
              ],
            ),
          ),

          // Amount and Stop button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                UtilityFunction.addCommaWithSign(
                  transaction.amount,
                  currencySymbol: currencySymbol,
                ),
                style: AppTextStyles.amount.copyWith(
                  fontSize: 18,
                  color: AppColors.negative,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              // Stop recurring button
              if (transaction.isRecurring)
                InkWell(
                  onTap: () => _showStopRecurringDialog(context, transaction),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.negative.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stop_circle_outlined,
                          size: 14,
                          color: AppColors.negative,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Stop',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.negative,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStopRecurringDialog(BuildContext context, Transaction transaction) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: context.appSurface,
          title: Text(
            'Stop Recurring Payment?',
            style: AppTextStyles.h3.copyWith(
              color: context.textPrimary,
            ),
          ),
          content: Text(
            'This will stop all future payments for "${transaction.title}". Past transactions will remain in your history.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                // Stop the recurring payment
                final transactionProvider = Provider.of<TransactionProvider>(
                  context,
                  listen: false,
                );
                await transactionProvider.stopRecurringPayment(transaction);

                // Show success message
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Recurring payment stopped',
                        style: TextStyle(color: context.textPrimary),
                      ),
                      backgroundColor: context.appSurface,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.negative,
                foregroundColor: Colors.white,
              ),
              child: const Text('Stop'),
            ),
          ],
        );
      },
    );
  }
}
