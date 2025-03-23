import 'package:flutter/material.dart';
import 'category_manger.dart';
import 'manage_budget.dart'; // Import the ManageBudgetScreen

class SettingsScreen extends StatelessWidget {
  static const routeName = '/settings';

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // Manage Categories option
        ListTile(
          leading: const Icon(Icons.category),
          title: const Text('Manage Categories'),
          onTap: () {
            // Navigate to the Category Management screen
            Navigator.pushNamed(context, CategoryManagementScreen.routeName);
          },
        ),
        // Manage Budget option
        ListTile(
          leading: const Icon(Icons.money),
          title: const Text('Manage Budget'),
          onTap: () {
            // Navigate to the Manage Budget screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ManageBudgetScreen()),
            );
          },
        ),
        // You can add more settings options here in the future
      ],
    );
  }
}
