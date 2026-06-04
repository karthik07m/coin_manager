import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../screens/transaction_form.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';
import '../providers/settings_provider.dart';

class TransactionItem extends StatefulWidget {
  final Transaction transaction;
  final Category? category;
  final bool enableDel;

  const TransactionItem(this.transaction, this.category,
      {this.enableDel = false, super.key});

  @override
  State<TransactionItem> createState() => _TransactionItemState();
}

class _TransactionItemState extends State<TransactionItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.spacing16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          boxShadow: AppShadows.card,
          border: Border.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          child: !widget.enableDel
              ? GestureDetector(
                  onTapDown: _handleTapDown,
                  onTapUp: _handleTapUp,
                  onTapCancel: _handleTapCancel,
                  onTap: () {
                    // Light haptic for transaction tap
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, TransactionForm.routeName,
                        arguments: widget.transaction.id);
                  },
                  child: _buildListTile(context),
                )
              : Dismissible(
                  key: Key(widget.transaction.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) => _showConfirmDialog(context),
                  onDismissed: (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: context.appSurface,
                        content: Text(
                          "Transaction '${widget.transaction.title}' removed",
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    );
                  },
                  movementDuration: const Duration(milliseconds: 200),
                  resizeDuration: const Duration(milliseconds: 150),
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
      ),
    );
  }

  Widget _buildListTile(BuildContext context) {
    final isExpense = widget.category?.isExpense == true;
    final amountColor = isExpense ? AppColors.negative : AppColors.positive;
    final iconBgColor = (isExpense ? AppColors.negative : AppColors.positive)
        .withValues(alpha: 0.1);

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
            child: widget.category != null
                ? Image.asset(
                    widget.category!.icon,
                    width: 24,
                    height: 24,
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
                  widget.transaction.title.isEmpty
                      ? widget.category?.name ?? 'Unknown Category'
                      : widget.transaction.title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.transaction.title.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.category?.name ?? 'Unknown Category',
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
              Selector<SettingsProvider, ({String symbol, String code})>(
                selector: (_, settings) => (
                  symbol: settings.currencySymbol,
                  code: settings.currencyCode,
                ),
                builder: (context, currency, _) {
                  return Text(
                    '${isExpense ? '-' : '+'}${UtilityFunction.addCommaWithSign(
                      widget.transaction.amount,
                      currencySymbol: currency.symbol,
                      currencyCode: currency.code,
                    )}',
                    style: AppTextStyles.amount.copyWith(
                      color: amountColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(context, widget.transaction.date),
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

  String _formatTime(BuildContext context, DateTime date) {
    final use24Hour = context.watch<SettingsProvider>().use24HourFormat;
    return UtilityFunction.formatTime(date, use24Hour: use24Hour);
  }

  Future<bool?> _showConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
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
                    .copyWith(color: context.textSecondary)),
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
