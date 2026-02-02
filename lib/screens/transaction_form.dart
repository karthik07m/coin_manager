import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/receipt.dart';
import '../models/account.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
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
  int selectedAccount = 1; // Default to Cash
  DateTime _selectedDate = DateTime.now();
  Transaction? _transaction;
  bool _isExpense = true;
  bool _isRecurring = false;
  Map<int, Category> categoryMap = {};
  Map<int, Account> accountMap = {};

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
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);

    Future.delayed(Duration.zero, () async {
      if (!mounted) return;
      final transactionId =
          ModalRoute.of(context)?.settings.arguments as String?;
      if (transactionId != null) {
        await loadTransactionDetails(transactionId);
      }
      if (!mounted) return;
      await _fetchAndMapCategories(categoryProvider);
      await _loadAccounts(accountProvider); // Make async and wait for load
    });
  }

  Future<void> _loadAccounts(AccountProvider accountProvider) async {
    // Ensure accounts are loaded first
    if (!accountProvider.isLoaded) {
      await accountProvider.loadAccounts();
    }

    if (!mounted) return;

    setState(() {
      accountMap = {for (var acc in accountProvider.accounts) acc.id!: acc};
      // Ensure we have a valid account selected
      if (!accountMap.containsKey(selectedAccount) && accountMap.isNotEmpty) {
        selectedAccount = accountMap.values.first.id ?? 1;
      }
    });
  }

  Future<void> _fetchAndMapCategories(CategoryProvider categoryProvider) async {
    // We intentionally fetch all categories to ensure proper mapping for existing transactions
    await categoryProvider.fetchCategories(_isExpense);

    setState(() {
      // Filter locally for the selection UI
      final allCategories = categoryProvider.categories;
      final filteredCategories =
          allCategories.where((c) => c.isExpense == _isExpense).toList();

      // Update the map for quick access (map should contain ALL categories)
      categoryMap = categoryProvider.categoryMap;

      // Ensure we have a valid category selected
      if (!categoryMap.containsKey(selectedCategory)) {
        // If current selection is invalid for the new type, pick the first valid one or default
        if (filteredCategories.isNotEmpty) {
          selectedCategory = filteredCategories.first.id!;
        } else {
          selectedCategory = _isExpense ? defaultExpenseCat : defaultIncomeCat;
        }
      } else {
        // If current selection is valid but wrong type (e.g. toggled type), switch to default
        final currentCat = categoryMap[selectedCategory];
        if (currentCat != null && currentCat.isExpense != _isExpense) {
          if (filteredCategories.isNotEmpty) {
            selectedCategory = filteredCategories.first.id!;
          } else {
            selectedCategory =
                _isExpense ? defaultExpenseCat : defaultIncomeCat;
          }
        }
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
        selectedAccount = _transaction!.accountId;
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
        if (result['date'] != null) {
          _selectedDate = result['date'] as DateTime;
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

  Future<void> _uploadReceipt() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _receiptImagePath = image.path;
      });
    }
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

  String getAccountName(int accountId) {
    final account = accountMap[accountId];
    if (account == null) return 'Cash';
    return account.name;
  }

  IconData getAccountIcon(int accountId) {
    final account = accountMap[accountId];
    if (account == null) return Icons.account_balance_wallet;

    switch (account.icon) {
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'account_balance':
        return Icons.account_balance;
      case 'credit_card':
        return Icons.credit_card;
      case 'payment':
        return Icons.payment;
      case 'savings':
        return Icons.savings;
      default:
        return Icons.account_balance_wallet;
    }
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
                    onPressed: () async {
                      await Navigator.of(context)
                          .pushNamed(CreateCategoryScreen.routeName);
                      // If a category was created, refresh the list
                      if (context.mounted) {
                        final categoryProvider = Provider.of<CategoryProvider>(
                            context,
                            listen: false);
                        await _fetchAndMapCategories(categoryProvider);
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<CategoryProvider>(
                builder: (context, categoryProvider, child) {
                  final categories = categoryProvider.categories
                      .where((c) => c.isExpense == _isExpense)
                      .toList();
                  return GridView.builder(
                    padding: const EdgeInsets.all(AppDimensions.spacing16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
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
                            gradient: isSelected
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.2),
                                      Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.05),
                                    ],
                                  )
                                : null,
                            color: isSelected
                                ? null
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusLarge),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.1),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.1)
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                ),
                                child: Image.asset(
                                  category.icon,
                                  width: 36,
                                  height: 36,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                    Icons.category,
                                    size: 36,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppDimensions.spacing12),
                              Text(
                                category.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.8),
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
        amount: double.parse(_amountController.text.replaceAll(',', '')),
        categoryId: selectedCategory,
        accountId: selectedAccount,
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
          // Receipt options
          PopupMenuButton<String>(
            icon: const Icon(Icons.receipt),
            tooltip: 'Receipt',
            onSelected: (value) {
              if (value == 'scan') {
                _scanReceipt();
              } else if (value == 'upload') {
                _uploadReceipt();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'scan',
                child: Row(
                  children: [
                    Icon(Icons.document_scanner),
                    SizedBox(width: 12),
                    Text('Scan Receipt'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'upload',
                child: Row(
                  children: [
                    Icon(Icons.upload_file),
                    SizedBox(width: 12),
                    Text('Upload Photo'),
                  ],
                ),
              ),
            ],
          ),
          if (_transaction?.id != null)
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: context.appSurface,
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
                              color: context.textSecondary,
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
                  Consumer<SettingsProvider>(
                    builder: (context, settings, child) {
                      return CalculatorTextFormField(
                        controller: _amountController,
                        currencySymbol: settings.currencySymbol,
                      );
                    },
                  ),
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
                  // Account Selector
                  InkWell(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (BuildContext context) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                    AppDimensions.spacing16),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Select Account',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 300,
                                child: ListView.builder(
                                  itemCount: accountMap.length,
                                  padding: const EdgeInsets.all(
                                      AppDimensions.spacing16),
                                  itemBuilder: (context, index) {
                                    // Sort accounts alphabetically by name
                                    final sortedAccounts = accountMap.values
                                        .toList()
                                      ..sort(
                                          (a, b) => a.name.compareTo(b.name));
                                    final account = sortedAccounts[index];
                                    final isSelected =
                                        selectedAccount == account.id;
                                    return ListTile(
                                      onTap: () {
                                        setState(() {
                                          selectedAccount = account.id!;
                                          Navigator.pop(context);
                                        });
                                      },
                                      leading: Icon(
                                        getAccountIcon(account.id!),
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                      ),
                                      title: Text(
                                        account.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                      ),
                                      trailing: isSelected
                                          ? Icon(Icons.check,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary)
                                          : null,
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
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
                            getAccountIcon(selectedAccount),
                            size: 28,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppDimensions.spacing12),
                          Text(
                            getAccountName(selectedAccount),
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
                  // Receipt Section
                  const SizedBox(height: AppDimensions.spacing8),
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 20,
                        color: context.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'RECEIPT',
                        style: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  // Receipt preview or buttons
                  if (_receiptImagePath != null)
                    Container(
                      margin: const EdgeInsets.only(
                          bottom: AppDimensions.spacing16),
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_receiptImagePath!),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: 56,
                              height: 56,
                              color: AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.receipt,
                                  size: 32, color: AppColors.primary),
                            ),
                          ),
                        ),
                        title: Text(
                          'Receipt Attached',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Tap to view full size',
                          style: AppTextStyles.caption.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.negative,
                          ),
                          onPressed: _removeReceipt,
                          tooltip: 'Remove receipt',
                        ),
                        onTap: _viewReceipt,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _scanReceipt,
                            icon: const Icon(Icons.document_scanner, size: 18),
                            label: const Text('Scan'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              side: BorderSide(
                                color: context.textSecondary
                                    .withValues(alpha: 0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _uploadReceipt,
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Upload'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              side: BorderSide(
                                color: context.textSecondary
                                    .withValues(alpha: 0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppDimensions.spacing20),
                  // Notes Section
                  Row(
                    children: [
                      Icon(
                        Icons.note_alt_outlined,
                        size: 20,
                        color: context.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'NOTES (OPTIONAL)',
                        style: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  Container(
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(
                        color: context.textSecondary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: TextFormField(
                      controller: _titleController,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Add notes about this transaction...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: context.textSecondary.withValues(alpha: 0.4),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        counterStyle: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                      maxLength: 500,
                      maxLines: null,
                      minLines: 3,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                    ),
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
