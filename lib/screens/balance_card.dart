import 'package:coin_manager/utilities/functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

import '../widgets/balance_item.dart';

class BalanceCard extends StatelessWidget {
  final double screenWidth;
  final double totalIncome;
  final double totalExpenses;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const BalanceCard({
    super.key,
    required this.screenWidth,
    required this.totalIncome,
    required this.totalExpenses,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    double balance = totalIncome - totalExpenses;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Balance',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                DropdownButton<DateTime>(
                  value: selectedMonth,
                  onChanged: (DateTime? newMonth) {
                    if (newMonth != null) {
                      onMonthChanged(newMonth);
                    }
                  },
                  items: List.generate(
                    12,
                    (index) {
                      final date = DateTime(DateTime.now().year, index + 1);
                      return DropdownMenuItem(
                        value: DateTime(date.year, date.month),
                        child: Text(DateFormat('MMM - yyyy').format(date)),
                      );
                    },
                  ),
                  underline: Container(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              UtilityFunction.addCommaWithSign(balance),
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const Divider(thickness: 1, height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                BalanceDetail(
                  label: 'Expenses',
                  amount: totalExpenses,
                  icon: Icons.arrow_downward,
                  color: Colors.redAccent,
                ),
                BalanceDetail(
                  label: 'Income',
                  amount: totalIncome,
                  icon: Icons.arrow_upward,
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
