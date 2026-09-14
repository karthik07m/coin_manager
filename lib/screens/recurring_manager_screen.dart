import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/responsive.dart';
import '../utilities/theme_helper.dart';

/// Manages every active recurring series — income *and* expense.
///
/// The "This Month" view only lists dates still ahead in the current month, so
/// a series whose date has already passed has no stop control there. This
/// screen lists one row per series, regardless of date, and can stop any of
/// them.
class RecurringManagerScreen extends StatefulWidget {
  static const routeName = '/recurring-manager';

  const RecurringManagerScreen({super.key});

  @override
  State<RecurringManagerScreen> createState() => _RecurringManagerScreenState();
}

class _RecurringManagerScreenState extends State<RecurringManagerScreen> {
  late Future<List<Transaction>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = Provider.of<TransactionProvider>(context, listen: false)
        .getRecurringSeries();
  }

  Future<void> _stop(Transaction transaction) async {
    final isIncome = !transaction.isExpense;
    final label = isIncome ? 'income' : 'payment';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Row(
          children: [
            const Icon(Icons.stop_circle_outlined,
                color: AppColors.warning, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Stop recurring?', style: AppTextStyles.h3),
            ),
          ],
        ),
        content: Text(
          '"${transaction.title}" will stop repeating. Entries already '
          'recorded stay in your history; only future ones are removed.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: context.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negative,
              foregroundColor: Colors.white,
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await Provider.of<TransactionProvider>(context, listen: false)
        .stopRecurringPayment(transaction);
    if (!mounted) return;

    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recurring $label stopped',
            style: TextStyle(color: context.textPrimary)),
        backgroundColor: context.appSurface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        title: const Text('Recurring'),
        elevation: 0,
      ),
      body: FutureBuilder<List<Transaction>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final series = snapshot.data ?? const <Transaction>[];
          if (series.isEmpty) return _emptyState(context);

          final income = series.where((t) => !t.isExpense).toList();
          final expenses = series.where((t) => t.isExpense).toList();

          return context.constrainedContent(
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (income.isNotEmpty) ...[
                  _sectionHeader(context, 'Income', income.length),
                  ...income.map((t) => _row(context, t, settings)),
                  const SizedBox(height: 20),
                ],
                if (expenses.isNotEmpty) ...[
                  _sectionHeader(context, 'Payments', expenses.length),
                  ...expenses.map((t) => _row(context, t, settings)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        '$label · $count',
        style: AppTextStyles.caption.copyWith(
          color: context.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    Transaction transaction,
    SettingsProvider settings,
  ) {
    final isIncome = !transaction.isExpense;
    final color = isIncome ? AppColors.positive : AppColors.negative;
    final categoryName = context
            .watch<CategoryProvider>()
            .categoryMap[transaction.categoryId]
            ?.name ??
        'Uncategorised';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: context.textSecondary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title.trim().isEmpty
                      ? categoryName
                      : transaction.title,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$categoryName · monthly on day ${transaction.date.day}',
                  style: AppTextStyles.caption
                      .copyWith(color: context.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                UtilityFunction.formatMoney(
                  transaction.amount,
                  symbol: settings.currencySymbol,
                  currencyCode: settings.currencyCode,
                  showDecimals: true,
                ),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              InkWell(
                onTap: () => _stop(transaction),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    'Stop',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.negative,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.repeat_rounded,
              size: 72, color: context.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Nothing repeating',
              style: AppTextStyles.h3.copyWith(color: context.textSecondary)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Recurring income and payments you set up will appear here, '
              'where you can stop them any time.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
