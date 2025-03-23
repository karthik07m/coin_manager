import 'package:coin_manager/utilities/functions.dart';
import 'package:flutter/material.dart';

class BalanceDetail extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const BalanceDetail({
    super.key,
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    Widget rowitem = Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 2),
        Text(UtilityFunction.addCommaWithSign(amount),
            style: TextStyle(fontSize: 18, color: color)),
      ],
    );
    return label == ""
        ? Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              rowitem
            ],
          )
        : rowitem;
  }
}
