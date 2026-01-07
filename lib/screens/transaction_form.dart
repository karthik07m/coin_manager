import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/receipt.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../utilities/constants.dart';
import '../widgets/calculator_field.dart';
import '../db/receipt_db_helper.dart';
import 'create_category.dart';
import 'receipt_scan_screen.dart';
import 'receipt_viewer_screen.dart';

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
  bool _isRecurring = false;
  Map<int, Category> categoryMap = {};

  // Receipt data
  String? _receiptImagePath;
  String? _receiptRawText;
  String? _receiptId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _amountController = TextEditingController();

    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    Future.delayed(Duration.zero, () async {
      if (!mounted) return;
      final transactionId =
          ModalRoute.of(context)?.settings.arguments as String?;
      if (transactionId != null) {
        await loadTransactionDetails(transactionId);
      }
      if (!mounted) return;
      await _fetchAndMapCategories(categoryProvider);
    });
  }

  Future<void> _fetchAndMapCategories(CategoryProvider categoryProvider) async {
    await categoryProvider.fetchCategories(_isExpense);
    setState(() {
      categoryMap = categoryProvider.categoryMap;
      // Ensure we have a valid category selected
      if (!categoryMap.containsKey(selectedCategory)) {
        selectedCategory = _isExpense ? defaultExpenseCat : defaultIncomeCat;
      }
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
        _isRecurring = _transaction!.isRecurring;
        _receiptId = _transaction!.receiptId;
        final categoryProvider =
            Provider.of<CategoryProvider>(context, listen: false);
        _fetchAndMapCategories(categoryProvider);
      });
      // Load receipt if exists
      if (_transaction!.receiptId != null) {
        _loadReceipt(_transaction!.receiptId!);
      }
    }
  }

  Future<void> _loadReceipt(String receiptId) async {
    final receiptDbHelper = ReceiptDBHelper();
    final receipt = await receiptDbHelper.getReceiptById(receiptId);
    if (receipt != null) {
      setState(() {
        _receiptImagePath = receipt.imagePath;
        _receiptRawText = receipt.extractedText;
        _receiptId = receipt.id;
      });
    }
  }

  Future<void> _scanReceipt() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (context) => const ReceiptScanScreen()),
    );

    if (result != null) {
      setState(() {
        _receiptImagePath = result['imagePath'] as String?;
        _receiptRawText = result['rawText'] as String?;
        if (result['title'] != null && _titleController.text.isEmpty) {
          _titleController.text = result['title'] as String;
        }
        if (result['amount'] != null && _amountController.text.isEmpty) {
          _amountController.text =
              (result['amount'] as double).toStringAsFixed(2);
        }
      });
    }
  }

  void _viewReceipt() {
    if (_receiptImagePath != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ReceiptViewerScreen(
            imagePath: _receiptImagePath!,
            title: _titleController.text.isNotEmpty
                ? _titleController.text
                : 'Receipt',
          ),
        ),
      );
    }
  }

  void _removeReceipt() {
    setState(() {
      _receiptImagePath = null;
      _receiptRawText = null;
      _receiptId = null;
    });
  }

  String getCategoryName(int categoryId) {
    final category = categoryMap[categoryId];
    if (category == null) {
      return 'Unknown';
    }
    return category.name;
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showCategorySelector() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Category',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
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
                    padding: const EdgeInsets.all(AppDimensions.spacing16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: AppDimensions.spacing16,
                      mainAxisSpacing: AppDimensions.spacing16,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (BuildContext context, int index) {
                      final category = categories[index];
                      final isSelected = selectedCategory == category.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCategory = category.id!;
                            Navigator.pop(context);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.1)
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusMedium),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                category.icon,
                                width: 32,
                                height: 32,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                  Icons.category,
                                  size: 32,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: AppDimensions.spacing8),
                              Text(
                                category.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                    ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
        );
      },
    );
  }

  Future<void> _saveData(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      String id = _transaction?.id ?? UniqueKey().toString();

      // Save receipt if we have a new one
      String? receiptIdToSave = _receiptId;
      if (_receiptImagePath != null && _receiptId == null) {
        final receiptDbHelper = ReceiptDBHelper();
        final newReceipt = Receipt(
          id: UniqueKey().toString(),
          transactionId: id,
          imagePath: _receiptImagePath!,
          extractedText: _receiptRawText,
          createdOn: DateTime.now(),
        );
        await receiptDbHelper.insertReceipt(newReceipt);
        receiptIdToSave = newReceipt.id;
      }

      Transaction newTransaction = Transaction.createNew(
        id: id,
        title: _titleController.text,
        amount: double.parse(_amountController.text),
        categoryId: selectedCategory,
        date: _selectedDate,
        isExpense: _isExpense,
        isRecurring: _isRecurring,
        receiptId: receiptIdToSave,
      );

      if (!context.mounted) return;

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
          _transaction?.id == null ? 'Add Transaction' : 'Edit Transaction',
          style: AppTextStyles.h2,
        ),
        actions: [
          // Scan receipt button
          IconButton(
            onPressed: _scanReceipt,
            icon: const Icon(Icons.document_scanner),
            tooltip: 'Scan Receipt',
          ),
          if (_transaction?.id != null)
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: Row(
                        children: [
                          const Icon(Icons.warning,
                              color: Colors.orange, size: 24),
                          const SizedBox(width: AppDimensions.spacing8),
                          Text(
                            "Delete Transaction",
                            style: AppTextStyles.h3,
                          ),
                        ],
                      ),
                      content: Text(
                        "Are you sure you want to delete this transaction?",
                        style: AppTextStyles.bodyMedium,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            "Cancel",
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Provider.of<TransactionProvider>(context,
                                    listen: false)
                                .deleteTransaction(_transaction!.id);
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          child: Text(
                            "Delete",
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.red,
                            ),
                          ),
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
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isExpense = true;
                                selectedCategory = defaultExpenseCat;
                                _fetchAndMapCategories(
                                    Provider.of<CategoryProvider>(context,
                                        listen: false));
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDimensions.spacing12,
                              ),
                              decoration: BoxDecoration(
                                color: _isExpense
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMedium),
                              ),
                              child: Text(
                                "Expense",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: _isExpense
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isExpense = false;
                                selectedCategory = defaultIncomeCat;
                                _fetchAndMapCategories(
                                    Provider.of<CategoryProvider>(context,
                                        listen: false));
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDimensions.spacing12,
                              ),
                              decoration: BoxDecoration(
                                color: !_isExpense
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMedium),
                              ),
                              child: Text(
                                "Income",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: !_isExpense
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing16),
                  CalculatorTextFormField(controller: _amountController),
                  const SizedBox(height: AppDimensions.spacing16),
                  InkWell(
                    onTap: _showCategorySelector,
                    child: Container(
                      padding: const EdgeInsets.all(AppDimensions.spacing12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            getCategoryIcon(selectedCategory),
                            width: 32,
                            height: 32,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.category,
                              size: 32,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacing12),
                          Text(
                            getCategoryName(selectedCategory),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing16),
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.all(AppDimensions.spacing12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 24,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppDimensions.spacing12),
                          Text(
                            DateFormat.yMMMd().format(_selectedDate),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing16),
                  Container(
                    margin:
                        const EdgeInsets.only(bottom: AppDimensions.spacing16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        'Recur every month',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      subtitle: Text(
                        'On day ${_selectedDate.day}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                      value: _isRecurring,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (bool value) {
                        setState(() {
                          _isRecurring = value;
                        });
                      },
                    ),
                  ),
                  // Receipt preview
                  if (_receiptImagePath != null)
                    Container(
                      margin: const EdgeInsets.only(
                          bottom: AppDimensions.spacing16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_receiptImagePath!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.receipt, size: 48),
                          ),
                        ),
                        title: const Text('Receipt Attached'),
                        subtitle: const Text('Tap to view'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: _removeReceipt,
                        ),
                        onTap: _viewReceipt,
                      ),
                    ),
                  TextFormField(
                    controller: _titleController,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      labelStyle:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                      hintText: 'Add notes about this transaction...',
                      hintStyle:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.3),
                              ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        borderSide: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        borderSide: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1,
                        ),
                      ),
                    ),
                    maxLength: 250,
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppDimensions.spacing24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _saveData(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.spacing16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMedium),
                        ),
                      ),
                      child: Text(
                        _transaction?.id == null
                            ? 'Add Transaction'
                            : 'Update Transaction',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
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
