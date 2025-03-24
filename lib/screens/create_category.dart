import 'package:coin_manager/models/category.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../utilities/constants.dart';

class CreateCategoryScreen extends StatefulWidget {
  static const routeName = '/create-category';

  const CreateCategoryScreen({super.key});

  @override
  CreateCategoryScreenState createState() => CreateCategoryScreenState();
}

class CreateCategoryScreenState extends State<CreateCategoryScreen> {
  final _nameController = TextEditingController();
  String _icon = 'assets/categories/other.png'; // Default icon
  bool _isExpense = true; // Default category type

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _selectIcon(String icon) {
    setState(() {
      _icon = icon;
    });
  }

  void _saveCategory() {
    if (_nameController.text.isEmpty) {
      return;
    }
    final name = _nameController.text;
    final icon = _icon;
    final isExpense = _isExpense;

    Provider.of<CategoryProvider>(context, listen: false)
        .addCategory(Category(name: name, icon: icon, isExpense: isExpense));

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Category'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Category Name'),
              ),
              const SizedBox(height: 16.0),
              const Text('Select Icon:'),
              GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                ),
                shrinkWrap: true, // Use only the space needed
                physics:
                    const NeverScrollableScrollPhysics(), // Disable scrolling inside GridView
                itemCount: categoryIcons.length,
                itemBuilder: (context, index) {
                  final icon = categoryIcons[index];
                  return GestureDetector(
                    onTap: () => _selectIcon(icon),
                    child: Card(
                      color: _icon == icon ? Colors.blueAccent : Colors.black,
                      child: Center(
                        child: Image.asset(
                          icon,
                          width: 40,
                          height: 40,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16.0),
              SwitchListTile(
                title: const Text('Expense'),
                value: _isExpense,
                onChanged: (value) {
                  setState(() {
                    _isExpense = value;
                  });
                },
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _saveCategory,
                child: const Text('Save Category'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
