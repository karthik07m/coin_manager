import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../models/category.dart';
import '../utilities/constants.dart';

class CategoryManagementScreen extends StatefulWidget {
  static const routeName = '/crud-category';
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  bool _isExpenseSelected = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  // Load categories based on the selected type (Income/Expense)
  Future<void> _loadCategories() async {
    await Provider.of<CategoryProvider>(context, listen: false)
        .fetchCategories(_isExpenseSelected);
  }

  // Method to toggle between Expense and Income
  void _toggleCategoryType(bool isExpense) {
    setState(() {
      _isExpenseSelected = isExpense;
    });
    _loadCategories(); // Fetch categories based on the selected type
  }

  Future<void> _addOrUpdateCategory({Category? category}) async {
    final categoryNameController = TextEditingController(
      text: category?.name ?? '',
    );
    final categoryIconController = TextEditingController(
      text: category?.icon ?? '',
    );

    bool isExpense = category?.isExpense ?? true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(category == null ? 'Add Category' : 'Edit Category'),
              content: SizedBox(
                width:
                    300, // Set a fixed width for the content to prevent overflow
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: categoryNameController,
                      decoration:
                          const InputDecoration(labelText: 'Category Name'),
                    ),
                    const SizedBox(height: 8),
                    const Text('Select Icon:'),
                    // GridView with fixed height, not requiring intrinsic calculations
                    SizedBox(
                      height: 200, // Fixed height for the GridView
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8.0,
                          mainAxisSpacing: 8.0,
                        ),
                        itemCount: categoryIcons.length,
                        itemBuilder: (context, index) {
                          final icon = categoryIcons[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                categoryIconController.text =
                                    icon; // Update icon on tap
                              });
                            },
                            child: Card(
                              color: categoryIconController.text == icon
                                  ? Colors.blueAccent
                                  : Colors.black,
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
                    ),
                    SwitchListTile(
                      title: const Text('Expense'),
                      value: isExpense,
                      onChanged: (value) {
                        setState(() {
                          isExpense = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newName = categoryNameController.text.trim();
                    final newIcon = categoryIconController.text.trim();

                    if (newName.isNotEmpty && newIcon.isNotEmpty) {
                      final newCategory = Category(
                        id: category?.id, // Use existing ID if updating
                        name: newName,
                        icon: newIcon,
                        isExpense: isExpense,
                        budget: category
                            ?.budget, // Retain existing budget if updating
                        createdOn:
                            category?.createdOn, // Retain existing created date
                        modifiedOn: DateTime.now().toIso8601String(),
                      );

                      if (category == null) {
                        // Add new category
                        await Provider.of<CategoryProvider>(context,
                                listen: false)
                            .addCategory(newCategory);
                      } else {
                        // Update existing category
                        await Provider.of<CategoryProvider>(context,
                                listen: false)
                            .updateCategory(newCategory);
                      }
                      Navigator.pop(context);
                    }
                  },
                  child: Text(category == null ? 'Add' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Category'),
          content: Text('Are you sure you want to delete "${category.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await Provider.of<CategoryProvider>(context, listen: false)
          .deleteCategory(category.id ?? 0); // Ensure valid ID
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addOrUpdateCategory(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category selection buttons (Income/Expense)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () =>
                    _toggleCategoryType(true), // Load Expense categories
                child: const Text('Expense'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () =>
                    _toggleCategoryType(false), // Load Income categories
                child: const Text('Income'),
              ),
            ],
          ),
          // Display categories based on the selection
          Expanded(
            child: Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                final categories = categoryProvider.categories;

                if (categories.isEmpty) {
                  return const Center(
                    child: Text('No categories found. Add one!'),
                  );
                }

                return ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      child: ListTile(
                        leading: category.icon.isNotEmpty
                            ? Image.asset(
                                category
                                    .icon, // Use the icon path stored in the category object
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.category),
                        title: Text(category.name),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _addOrUpdateCategory(category: category);
                            } else if (value == 'delete') {
                              _deleteCategory(category);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
