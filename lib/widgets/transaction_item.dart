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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: !enableDel
          ? InkWell(
              onTap: () {
                Navigator.pushNamed(context, TransactionForm.routeName,
                    arguments: transaction.id);
              },
              borderRadius: BorderRadius.circular(12),
              child: _buildListTile(),
            )
          : Dismissible(
              key: Key(transaction.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) => _showConfirmDialog(context),
              onDismissed: (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Transaction '${transaction.title}' removed",
                    ),
                  ),
                );
              },
              background: Container(
                color: Theme.of(context).colorScheme.error,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white, size: 40),
              ),
              child: _buildListTile(),
            ),
    );
  }

  Widget _buildListTile() {
    final isExpense = category?.isExpense == true;
    final amountColor =
        isExpense ? const Color(0xFFE53935) : const Color(0xFF43A047);
    final bgColor =
        isExpense ? const Color(0xFFFBE9E7) : const Color(0xFFE8F5E9);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          category != null
              ? Image.asset(
                  category!.icon,
                  width: 28,
                  height: 28,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.category,
                    size: 28,
                    color: Colors.grey.shade600,
                  ),
                )
              : Icon(
                  Icons.help_outline,
                  size: 28,
                  color: Colors.grey.shade400,
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title.isEmpty
                      ? category?.name ?? 'Unknown Category'
                      : transaction.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (transaction.title.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    category?.name ?? 'Unknown Category',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\$${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: amountColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(transaction.date),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.1,
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
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 22),
            SizedBox(width: 4),
            Text('Are you sure?'),
          ],
        ),
        content: const Text('Do you want to remove this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Yes"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("No"),
          ),
        ],
      ),
    );
  }
}
