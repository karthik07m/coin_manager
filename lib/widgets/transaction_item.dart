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
import '../providers/account_provider.dart';

class TransactionItem extends StatefulWidget {
  final Transaction transaction;
  final Category? category;
  final bool enableDel;

  /// Multi-select support. When [selectionMode] is on, a tap toggles
  /// [selected] via [onSelectToggle] instead of opening the transaction;
  /// [onLongPress] is used to enter selection mode from a normal tap state.
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onLongPress;

  const TransactionItem(this.transaction, this.category,
      {this.enableDel = false,
      this.selectionMode = false,
      this.selected = false,
      this.onSelectToggle,
      this.onLongPress,
      super.key});

  @override
  State<TransactionItem> createState() => _TransactionItemState();
}

class _TransactionItemState extends State<TransactionItem> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    setState(() {
      _isPressed = true;
    });
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() {
      _isPressed = false;
    });
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
  }

  void _openTransaction() {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(
      context,
      TransactionForm.routeName,
      arguments: widget.transaction.id,
    );
  }

  Widget _buildTappableCard(BuildContext context) {
    final accent = context.appAccent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: () {
        if (widget.selectionMode) {
          widget.onSelectToggle?.call();
        } else {
          _openTransaction();
        }
      },
      onLongPress: widget.onLongPress,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.selected
              ? accent.withValues(alpha: 0.10)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          boxShadow: AppShadows.card,
          border: Border.all(
            color: widget.selected
                ? accent
                : Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.5),
            width: widget.selected ? 1.5 : 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          child: Stack(
            children: [
              _buildListTile(context),
              if (widget.selectionMode)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: widget.selected
                          ? accent
                          : Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: widget.selected
                        ? const Icon(Icons.check,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 0.985 : 1,
      duration: AppDurations.fastest,
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.spacing16),
        child: !widget.enableDel
            ? _buildTappableCard(context)
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
                child: _buildTappableCard(context),
              ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context) {
    if (widget.transaction.isTransfer) {
      return _buildTransferTile(context);
    }
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
              Selector<SettingsProvider, bool>(
                selector: (_, settings) => settings.use24HourFormat,
                builder: (context, use24Hour, _) {
                  return Text(
                    UtilityFunction.formatTime(
                      widget.transaction.date,
                      use24Hour: use24Hour,
                    ),
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransferTile(BuildContext context) {
    final accountProvider = context.read<AccountProvider>();
    String nameFor(int? id) {
      for (final acc in accountProvider.accounts) {
        if (acc.id == id) return acc.name;
      }
      return 'Account';
    }

    final from = nameFor(widget.transaction.accountId);
    final to = nameFor(widget.transaction.transferAccountId);

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            decoration: BoxDecoration(
              color: context.appAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.swap_horiz_rounded,
                size: 24, color: context.appAccent),
          ),
          const SizedBox(width: AppDimensions.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfer',
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$from → $to',
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Selector<SettingsProvider, ({String symbol, String code})>(
            selector: (_, settings) => (
              symbol: settings.currencySymbol,
              code: settings.currencyCode,
            ),
            builder: (context, currency, _) {
              return Text(
                UtilityFunction.addCommaWithSign(
                  widget.transaction.amount,
                  currencySymbol: currency.symbol,
                  currencyCode: currency.code,
                ),
                style: AppTextStyles.amount.copyWith(
                  color: context.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ],
      ),
    );
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
