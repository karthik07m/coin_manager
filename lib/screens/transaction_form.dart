import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../utilities/constants.dart';
import '../widgets/calculator_field.dart';
import 'create_category.dart';

class TransactionForm extends StatefulWidget {
  static const routeName = "/addTransaction";
  const TransactionForm({super.key});

  @override
  TransactionFormState createState() => TransactionFormState();
}

class TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  int selectedCategory = defaultExpenseCat;
  DateTime _selectedDate = DateTime.now();
  Transaction? _transaction;
  bool _isExpense = true;
  Map<int, Category> categoryMap = {};

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _amountController = TextEditingController();

    Future.delayed(Duration.zero, () {
      final transactionId =
          ModalRoute.of(context)?.settings.arguments as String?;
      if (transactionId != null) {
        loadTransactionDetails(transactionId);
      }
    });

    _fetchAndMapCategories();
  }

  Future<void> _fetchAndMapCategories() async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    await categoryProvider.fetchCategories(_isExpense);
    setState(() {
      categoryMap = {
        for (var category in categoryProvider.categories) category.id!: category
      };
    });
  }

  Future<void> loadTransactionDetails(String id) async {
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    _transaction = await transactionProvider.getTransactionById(id);
    if (_transaction != null) {
      setState(() {
        _titleController.text = _transaction!.title;
        _amountController.text = _transaction!.amount.toString();
        selectedCategory = _transaction!.categoryId;
        _selectedDate = _transaction!.date;
        _isExpense = _transaction!.isExpense;
        _fetchAndMapCategories();
      });
    }
  }

  String getCategoryName(int categoryId) {
    return categoryMap[categoryId]?.name ?? 'Unknown';
  }

  String getCategoryIcon(int categoryId) {
    return categoryMap[categoryId]?.icon ?? 'assets/categories/other.png';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015, 8),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void showCategories() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add a New Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      Navigator.of(context)
                          .pushNamed(CreateCategoryScreen.routeName);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<CategoryProvider>(
                builder: (context, categoryProvider, child) {
                  final categories = categoryProvider.categories;
                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (BuildContext context, int index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCategory = categories[index].id!;
                            Navigator.pop(context);
                          });
                        },
                        child: Card(
                          color: selectedCategory == categories[index].id
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  categories[index].icon,
                                  width: 40,
                                  height: 40,
                                ),
                                const SizedBox(height: 8),
                                Text(categories[index].name),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _saveData(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      String id = _transaction?.id ?? UniqueKey().toString();

      Transaction newTransaction = Transaction.createNew(
        id: id,
        title: _titleController.text,
        amount: double.parse(_amountController.text),
        categoryId: selectedCategory,
        date: _selectedDate,
        isExpense: _isExpense,
      );

      if (_transaction?.id != null) {
        Provider.of<TransactionProvider>(context, listen: false)
            .updateTransaction(newTransaction);
      } else {
        Provider.of<TransactionProvider>(context, listen: false)
            .addTransaction(newTransaction);
      }

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _transaction?.id == null ? 'Add Transaction' : 'Edit Transaction'),
        actions: [
          if (_transaction?.id != null)
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text("Confirm Delete"),
                      content: const Text(
                          "Are you sure you want to delete this transaction?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            Provider.of<TransactionProvider>(context,
                                    listen: false)
                                .deleteTransaction(_transaction!.id);
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          child: const Text("Delete",
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Icons.delete, color: Colors.red),
            )
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isExpense
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[200],
                          ),
                          onPressed: () {
                            setState(() {
                              _isExpense = true;
                              selectedCategory = defaultExpenseCat;
                              _fetchAndMapCategories();
                            });
                          },
                          child: Text(
                            "Expense",
                            style: TextStyle(
                              color: _isExpense ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !_isExpense
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[200],
                          ),
                          onPressed: () {
                            setState(() {
                              _isExpense = false;
                              selectedCategory = defaultIncomeCat;
                              _fetchAndMapCategories();
                            });
                          },
                          child: Text(
                            "Income",
                            style: TextStyle(
                              color: !_isExpense ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CalculatorTextFormField(controller: _amountController),
                  const SizedBox(height: 10),
                  Consumer<CategoryProvider>(
                    builder: (ctx, categoryProvider, _) {
                      return InkWell(
                        onTap: showCategories,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(width: 1, color: Colors.grey),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(10.0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Image.asset(
                                  getCategoryIcon(selectedCategory),
                                  width: 40,
                                  height: 40,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  getCategoryName(selectedCategory),
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(width: 1, color: Colors.grey),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10.0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Colors.greenAccent),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat.yMMMd().format(_selectedDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Items...',
                      labelText: 'Item(s) / Notes',
                    ),
                    maxLength: 250,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _saveData(context),
                    child: Text(_transaction?.id == null
                        ? 'Add Transaction'
                        : 'Update Transaction'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
