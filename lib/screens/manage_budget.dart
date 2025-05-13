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
  double _totalBudget = 0.0;
  double _remainingBudget = 0.0;

  @override
  void initState() {
    super.initState();
    final categories = Provider.of<CategoryProvider>(context, listen: false).categories;
    final monthlyBudgetProvider = Provider.of<MonthlyBudgetProvider>(context, listen: false);

    for (var category in categories) {
      final budget = monthlyBudgetProvider.getBudget(category.name, DateTime.now().month.toString());
      _budgets[category.name] = budget;
    }

    _totalBudget = monthlyBudgetProvider.getTotalBudget(DateTime.now().month.toString());
    _calculateRemaining();
  }

  void _calculateRemaining() {
    final used = _budgets.values.fold(0.0, (sum, val) => sum + val);
    setState(() {
      _remainingBudget = _totalBudget - used;
    });
  }

  void _saveBudgets() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final totalUsed = _budgets.values.fold(0.0, (sum, val) => sum + val);
      if (totalUsed > _totalBudget) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Total of category budgets exceeds total budget')),
        );
        return;
      }

      final monthlyBudgetProvider = Provider.of<MonthlyBudgetProvider>(context, listen: false);
      monthlyBudgetProvider.setTotalBudget(DateTime.now().month.toString(), _totalBudget);

      _budgets.forEach((categoryName, budget) {
        monthlyBudgetProvider.setBudget(categoryName, DateTime.now().month.toString(), budget);
      });

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = Provider.of<CategoryProvider>(context).categories;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Budget')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Total Monthly Budget / Income',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                initialValue: _totalBudget > 0 ? _totalBudget.toString() : '',
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter total income';
                  return null;
                },
                onChanged: (value) {
                  final parsed = double.tryParse(value) ?? 0;
                  setState(() {
                    _totalBudget = parsed;
                    _calculateRemaining();
                  });
                },
                onSaved: (value) {
                  if (value != null) _totalBudget = double.parse(value);
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Remaining Budget: \$${_remainingBudget.toStringAsFixed(2)}',
                style: TextStyle(
                  color: _remainingBudget < 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ...categories.map((category) {
                return Row(
                  children: [
                    Image.asset(category.icon, width: 40, height: 40),
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
                          if (value == null || value.isEmpty) return 'Enter amount';
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            _budgets[category.name] = double.tryParse(value) ?? 0;
                            _calculateRemaining();
                          });
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
