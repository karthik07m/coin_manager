import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../screens/transaction_form.dart';
import '../utilities/constants.dart';

class TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final bool enableDel;

  const TransactionItem(this.transaction, this.category,
      {this.enableDel = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        boxShadow: AppShadows.card,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: !enableDel
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(context, TransactionForm.routeName,
                        arguments: transaction.id);
                  },
                  child: _buildListTile(context),
                ),
              )
            : Dismissible(
                key: Key(transaction.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) => _showConfirmDialog(context),
                onDismissed: (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.surface,
                      content: Text(
                        "Transaction '${transaction.title}' removed",
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  );
                },
                background: Container(
                  color: AppColors.negative,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child:
                      const Icon(Icons.delete, color: Colors.white, size: 28),
                ),
                child: _buildListTile(context),
              ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context) {
    final isExpense = category?.isExpense == true;
    final amountColor = isExpense ? AppColors.negative : AppColors.positive;
    final iconBgColor =
        (isExpense ? AppColors.negative : AppColors.positive).withValues(alpha: 0.1);

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: category != null
                ? Image.asset(
                    category!.icon,
                    width: 24,
                    height: 24,
                    // Colors removed to show original icon
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.category_outlined,
                      size: 24,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  )
                : Icon(
                    Icons.help_outline,
                    size: 24,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
          ),
          const SizedBox(width: AppDimensions.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title.isEmpty
                      ? category?.name ?? 'Unknown Category'
                      : transaction.title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (transaction.title.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    category?.name ?? 'Unknown Category',
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isExpense ? '-' : '+'} \$${transaction.amount.toStringAsFixed(2)}',
                style: AppTextStyles.amount.copyWith(
                  color: amountColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(transaction.date),
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<bool?> _showConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 24),
            const SizedBox(width: 8),
            Text('Delete Transaction?', style: AppTextStyles.h3),
          ],
        ),
        content: Text(
          'This action cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("Cancel",
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("Delete",
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.negative)),
          ),
        ],
      ),
    );
  }
}
