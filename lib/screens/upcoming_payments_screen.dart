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
import 'transaction_form.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(context, listen: false)
          .loadAllUpcomingTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('Recurring Transactions'),
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
                    Icons.repeat_outlined,
                    size: 64,
                    color: context.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Recurring Transactions',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mark a transaction as recurring to see it here',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final totalExpense = upcomingList
              .where((t) => t.isExpense)
              .fold<double>(0.0, (sum, t) => sum + t.amount);
          final totalIncome = upcomingList
              .where((t) => !t.isExpense)
              .fold<double>(0.0, (sum, t) => sum + t.amount);

          return Column(
            children: [
              // Summary card — split income / expense
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
                  children: [
                    // Expense column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EXPENSES',
                            style: AppTextStyles.caption.copyWith(
                              color: context.textSecondary,
                              letterSpacing: 1.2,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            UtilityFunction.addCommaWithSign(
                              totalExpense,
                              currencySymbol: currencySymbol,
                            ),
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.negative,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(
                      width: 1,
                      height: 36,
                      color: context.textSecondary.withValues(alpha: 0.2),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    // Income column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INCOME',
                            style: AppTextStyles.caption.copyWith(
                              color: context.textSecondary,
                              letterSpacing: 1.2,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            UtilityFunction.addCommaWithSign(
                              totalIncome,
                              currencySymbol: currencySymbol,
                            ),
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.positive,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${upcomingList.length} Total',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // List
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
    final Color amountColor =
        transaction.isExpense ? AppColors.negative : AppColors.positive;

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
        border: Border.all(
          color: amountColor.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Category icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.12),
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
                      color: amountColor,
                    ),
                  )
                : Icon(
                    Icons.category_outlined,
                    size: 24,
                    color: amountColor,
                  ),
          ),
          const SizedBox(width: 16),

          // Title + date
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
                    // Income / Expense badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: amountColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        transaction.isExpense ? 'Expense' : 'Income',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: amountColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateString,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isToday ? amountColor : context.textSecondary,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (daysUntil <= 3 && !isToday) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${daysUntil}d',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Amount + actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${transaction.isExpense ? '-' : '+'}${UtilityFunction.addCommaWithSign(
                  transaction.amount,
                  currencySymbol: currencySymbol,
                )}',
                style: AppTextStyles.amount.copyWith(
                  fontSize: 16,
                  color: amountColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              // Edit + Stop row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Edit button
                  _ActionChip(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    color: AppColors.primary,
                    onTap: () => _editTransaction(context, transaction),
                  ),
                  const SizedBox(width: 6),
                  // Stop button
                  if (transaction.isRecurring)
                    _ActionChip(
                      icon: Icons.stop_circle_outlined,
                      label: 'Stop',
                      color: AppColors.negative,
                      onTap: () =>
                          _showStopRecurringDialog(context, transaction),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _editTransaction(BuildContext context, Transaction transaction) {
    Navigator.of(context).pushNamed(
      TransactionForm.routeName,
      arguments: transaction.id,
    );
  }

  void _showStopRecurringDialog(BuildContext context, Transaction transaction) {
    final label = transaction.isExpense ? 'payment' : 'income';
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: context.appSurface,
          title: Text(
            'Stop Recurring ${transaction.isExpense ? 'Payment' : 'Income'}?',
            style: AppTextStyles.h3.copyWith(
              color: context.textPrimary,
            ),
          ),
          content: Text(
            'This will stop all future $label entries for "${transaction.title.isEmpty ? 'this transaction' : transaction.title}". Past entries will remain in your history.',
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

                final transactionProvider = Provider.of<TransactionProvider>(
                  context,
                  listen: false,
                );
                await transactionProvider.stopRecurringPayment(transaction);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Recurring $label stopped',
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

/// Small tappable chip used for Edit / Stop actions.
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
