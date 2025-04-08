import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/monthly_budget_provider.dart';
import '../providers/category_provider.dart';

class ManageBudgetScreen extends StatefulWidget {
  const ManageBudgetScreen({super.key});

  @override
  _ManageBudgetScreenState createState() => _ManageBudgetScreenState();
}

class _ManageBudgetScreenState extends State<ManageBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, double> _budgets = {};

  @override
  void initState() {
    super.initState();
    // Load existing categories and their budgets
    final categories =
        Provider.of<CategoryProvider>(context, listen: false).categories;
    final monthlyBudgetProvider =
        Provider.of<MonthlyBudgetProvider>(context, listen: false);

    for (var category in categories) {
      _budgets[category.name] = monthlyBudgetProvider.getBudget(
          category.name, DateTime.now().month.toString());
    }
  }

  void _saveBudgets() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // Save budgets to the provider
      final monthlyBudgetProvider =
          Provider.of<MonthlyBudgetProvider>(context, listen: false);
      _budgets.forEach((categoryName, budget) {
        monthlyBudgetProvider.setBudget(
            categoryName, DateTime.now().month.toString(), budget);
      });
      Navigator.pop(context); // Go back to the previous screen
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = Provider.of<CategoryProvider>(context).categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Budget'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              ...categories.map((category) {
                return Row(
                  children: [
                    Image.asset(
                      category.icon, // Assuming category has an icon field
                      width: 40,
                      height: 40,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: category.name,
                          hintText: 'Enter budget for ${category.name}',
                        ),
                        keyboardType: TextInputType.number,
                        initialValue: _budgets[category.name]?.toString(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a budget';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          if (value != null) {
                            _budgets[category.name] = double.parse(value);
                          }
                        },
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveBudgets,
                child: const Text('Save Budgets'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
