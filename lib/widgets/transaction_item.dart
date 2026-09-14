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
import '../providers/debt_provider.dart';
import 'tappable.dart';

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
  Widget _buildTappableCard(BuildContext context) {
    final accent = context.appAccent;
    return Tappable(
      color: widget.selected
          ? Color.alphaBlend(accent.withValues(alpha: 0.10), context.appSurface)
          : context.appSurface,
      borderRadius: AppDimensions.radiusMedium,
      pressedScale: 0.98,
      // In selection mode a tap toggles the row instead of opening it.
      onTap: widget.selectionMode
          ? widget.onSelectToggle
          : () => HapticFeedback.lightImpact(),
      openPage: widget.selectionMode
          ? null
          : TransactionForm(transaction: widget.transaction),
      onLongPress: widget.onLongPress,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          // Outline only when selected; otherwise the fill separates the row.
          border: widget.selected
              ? Border.all(color: accent, width: 1.5)
              : context.cardBorder,
        ),
        // No ClipRRect: nothing inside overflows the rounded box, and a clip
        // per row was pure cost on long scrolling lists.
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
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing8),
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
                child: const Icon(Icons.delete, color: Colors.white, size: 28),
              ),
              child: _buildTappableCard(context),
            ),
    );
  }

  Widget _buildListTile(BuildContext context) {
    if (widget.transaction.isTransfer) {
      return _buildTransferTile(context);
    }
    final isExpense = widget.category?.isExpense == true;
    final amountColor = isExpense ? AppColors.negative : AppColors.positive;
    // Neutral backing: the amount's colour already says income vs expense,
    // so tinting every icon red or green too was saying it twice.
    final iconBgColor = context.textPrimary.withValues(alpha: 0.06);

    // Show the amount in its account's own currency (multi-currency); totals
    // elsewhere convert to the base currency.
    final acct = context
        .read<AccountProvider>()
        .getAccountById(widget.transaction.accountId);
    final acctCode =
        (acct != null && acct.currency.isNotEmpty) ? acct.currency : null;
    // Loans and repayments look like any other expense/income; say who the
    // money went to or came from so the row isn't mistaken for spending.
    final debtLink =
        context.watch<DebtProvider>().linkFor(widget.transaction.id);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing12,
      ),
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
                if (debtLink != null) ...[
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.handshake_outlined,
                        size: 12, color: context.appAccent),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        debtLink.label,
                        style: AppTextStyles.caption.copyWith(
                            color: context.appAccent,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
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
                      currencySymbol: acctCode != null
                          ? currencySymbolForCode(acctCode)
                          : currency.symbol,
                      currencyCode: acctCode ?? currency.code,
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing12,
      ),
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
