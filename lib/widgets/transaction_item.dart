import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../screens/transaction_form.dart';

class TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final bool enableDel;

  const TransactionItem(this.transaction, this.category,
      {this.enableDel = false, super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      // Navigate to the transaction form screen for editing
      onTap: () {
        Navigator.pushNamed(context, TransactionForm.routeName,
            arguments: transaction.id);
      },
      child: Card(
        child: !enableDel
            ? _buildListTile()
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
                  child:
                      const Icon(Icons.delete, color: Colors.white, size: 40),
                ),
                child: _buildListTile(),
              ),
      ),
    );
  }

  ListTile _buildListTile() {
    return ListTile(
      leading: category != null
          ? Image.asset(
              category!.icon,
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.category, size: 40),
            )
          : const Icon(Icons.help_outline, size: 40),
      title: Text(transaction.title.isEmpty
          ? category?.name ?? 'Unknown Category'
          : transaction.title),
      subtitle: Text(category?.name ?? 'Unknown Category'),
      trailing: Chip(
        backgroundColor:
            category?.isExpense == true ? Colors.redAccent : Colors.green,
        label: Text(
          '\$${transaction.amount.toStringAsFixed(2)}',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
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
