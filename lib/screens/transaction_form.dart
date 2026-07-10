import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:math_expressions/math_expressions.dart';

import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../utilities/id_generator.dart';
import '../models/debt.dart';
import '../models/transaction.dart';
import '../models/receipt.dart';
import '../models/account.dart';
import '../providers/debt_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../db/receipt_db_helper.dart';
import 'create_category.dart';
import 'receipt_scan_screen.dart';
import 'receipt_viewer_screen.dart';

/// Cashew-style loan marker: a transaction can be flagged as money lent
/// (someone owes me) or borrowed (I owe someone), which also creates an
/// entry in the Debt Tracker on save.
enum _LoanKind { lent, borrowed }

/// Keypad-first entry screen, like mainstream expense trackers:
/// the number pad is part of the screen, the amount is the hero, and
/// category/account/date are one-tap chips. No scrolling for the core flow.
class TransactionForm extends StatefulWidget {
  static const routeName = "/addTransaction";
  const TransactionForm({super.key});

  @override
  TransactionFormState createState() => TransactionFormState();
}

class TransactionFormState extends State<TransactionForm> {
  late TextEditingController _titleController;
  final FocusNode _noteFocusNode = FocusNode();
  String _amountExpression = '0';
  int selectedCategory = defaultExpenseCat;
  int selectedAccount = 1; // Default to Cash
  DateTime _selectedDate = DateTime.now();
  Transaction? _transaction;
  bool _isExpense = true;
  bool _isRecurring = false;
  Map<int, Category> categoryMap = {};
  Map<int, Account> accountMap = {};

  // Auto-suggests the category last used for a repeated title (e.g. typing
  // "Starbucks" again picks the category you filed it under last time).
  Timer? _titleDebounce;
  bool _categoryManuallySelected = false;

  // Receipt data
  String? _receiptImagePath;
  String? _receiptRawText;
  String? _receiptId;

  // Loan marker (lent/borrowed) — creates a Debt Tracker entry on save.
  _LoanKind? _loanKind;
  final TextEditingController _loanPersonController = TextEditingController();

  bool get _hasOperator => _amountExpression.contains(RegExp(r'[+\-×÷]'));

  double get _enteredAmount {
    final evaluated = _evaluateExpression(_amountExpression);
    return evaluated ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _titleController.addListener(_onTitleChanged);
    _noteFocusNode.addListener(_handleNoteFocusChanged);

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
      await _loadAccounts(accountProvider);
    });
  }

  void _handleNoteFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAccounts(AccountProvider accountProvider) async {
    if (!accountProvider.isLoaded) {
      await accountProvider.loadAccounts();
    }

    if (!mounted) return;

    setState(() {
      accountMap = {for (var acc in accountProvider.accounts) acc.id!: acc};
      if (_transaction == null) {
        // New transaction → start on the user's default account (fall back to
        // the first account). Editing keeps the transaction's own account.
        final defaultId = accountProvider.defaultAccount?.id;
        if (defaultId != null && accountMap.containsKey(defaultId)) {
          selectedAccount = defaultId;
        } else if (accountMap.isNotEmpty) {
          selectedAccount = accountMap.values.first.id ?? selectedAccount;
        }
      } else if (!accountMap.containsKey(selectedAccount) &&
          accountMap.isNotEmpty) {
        selectedAccount = accountMap.values.first.id ?? 1;
      }
    });
  }

  Future<void> _fetchAndMapCategories(CategoryProvider categoryProvider) async {
    // We intentionally fetch all categories to ensure proper mapping for existing transactions
    await categoryProvider.fetchCategories(_isExpense);

    setState(() {
      final allCategories = categoryProvider.categories;
      final filteredCategories =
          allCategories.where((c) => c.isExpense == _isExpense).toList();

      categoryMap = categoryProvider.categoryMap;

      if (!categoryMap.containsKey(selectedCategory)) {
        if (filteredCategories.isNotEmpty) {
          selectedCategory = filteredCategories.first.id!;
        } else {
          selectedCategory = _isExpense ? defaultExpenseCat : defaultIncomeCat;
        }
      } else {
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

  void _onTitleChanged() {
    if (_transaction != null || _categoryManuallySelected) return;
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 500), () {
      _maybeSuggestCategoryForTitle();
    });
  }

  Future<void> _maybeSuggestCategoryForTitle() async {
    if (_transaction != null || _categoryManuallySelected) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final suggestedCategoryId =
        await transactionProvider.getLastCategoryForTitle(title, _isExpense);

    if (!mounted ||
        suggestedCategoryId == null ||
        _transaction != null ||
        _categoryManuallySelected) {
      return;
    }

    if (categoryMap.containsKey(suggestedCategoryId) &&
        suggestedCategoryId != selectedCategory) {
      setState(() {
        selectedCategory = suggestedCategoryId;
      });
    }
  }

  Future<void> loadTransactionDetails(String id) async {
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    _transaction = await transactionProvider.getTransactionById(id);
    if (_transaction != null) {
      setState(() {
        _titleController.text = _transaction!.title;
        _amountExpression = _formatAmountForDisplay(_transaction!.amount);
        selectedCategory = _transaction!.categoryId;
        selectedAccount = _transaction!.accountId;
        _categoryManuallySelected = true;
        _selectedDate = _transaction!.date;
        _isExpense = _transaction!.isExpense;
        _isRecurring = _transaction!.isRecurring;
        _receiptId = _transaction!.receiptId;
        final categoryProvider =
            Provider.of<CategoryProvider>(context, listen: false);
        _fetchAndMapCategories(categoryProvider);
      });
      if (_transaction!.receiptId != null) {
        _loadReceipt(_transaction!.receiptId!);
      }
    }
  }

  String _formatAmountForDisplay(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toString();
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
        if (result['amount'] != null && _enteredAmount == 0) {
          _amountExpression =
              _formatAmountForDisplay(result['amount'] as double);
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
      return 'Category';
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
    _titleDebounce?.cancel();
    _noteFocusNode.removeListener(_handleNoteFocusChanged);
    _noteFocusNode.dispose();
    _titleController.dispose();
    _loanPersonController.dispose();
    super.dispose();
  }

  // ==================== Keypad logic ====================

  void _onKeyTap(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      String value = _amountExpression;
      if (value == '0') value = '';

      if (['+', '-', '×', '÷'].contains(key)) {
        if (value.isEmpty) return;
        // Replace a trailing operator instead of stacking them.
        if (RegExp(r'[+\-×÷]$').hasMatch(value)) {
          value = value.substring(0, value.length - 1);
        }
        _amountExpression = value + key;
      } else if (key == '.') {
        final segments = value.split(RegExp(r'[+\-×÷]'));
        if (segments.isEmpty || !segments.last.contains('.')) {
          _amountExpression = value.isEmpty ? '0.' : '$value.';
        }
      } else {
        if (value.length >= 18) return; // keep the display sane
        _amountExpression = value + key;
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_amountExpression.isNotEmpty && _amountExpression != '0') {
        _amountExpression =
            _amountExpression.substring(0, _amountExpression.length - 1);
        if (_amountExpression.isEmpty) _amountExpression = '0';
      }
    });
  }

  void _onClearAll() {
    HapticFeedback.mediumImpact();
    setState(() => _amountExpression = '0');
  }

  double? _evaluateExpression(String raw) {
    try {
      String expression =
          raw.replaceAll(',', '').replaceAll('×', '*').replaceAll('÷', '/');
      // Drop a trailing operator so "12+" still evaluates.
      expression = expression.replaceAll(RegExp(r'[+\-*/]$'), '');
      if (expression.isEmpty) return 0;

      if (expression.contains(RegExp(r'[+\-*/]'))) {
        final parser = GrammarParser();
        final exp = parser.parse(expression);
        final result = RealEvaluator(ContextModel()).evaluate(exp);
        final value = result.toDouble();
        return value.isFinite ? value : null;
      }
      return double.tryParse(expression);
    } catch (e) {
      return null;
    }
  }

  void _onEvaluate() {
    HapticFeedback.selectionClick();
    final value = _evaluateExpression(_amountExpression);
    if (value == null) return;
    setState(() {
      _amountExpression =
          _formatAmountForDisplay(double.parse(value.toStringAsFixed(2)));
    });
  }

  // ==================== Pickers ====================

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015, 8),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      HapticFeedback.selectionClick();
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
                    tooltip: 'Create category',
                    onPressed: () async {
                      await Navigator.of(context)
                          .pushNamed(CreateCategoryScreen.routeName);
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
                      crossAxisCount: 4,
                      childAspectRatio: 0.82,
                      crossAxisSpacing: AppDimensions.spacing12,
                      mainAxisSpacing: AppDimensions.spacing12,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (BuildContext context, int index) {
                      final category = categories[index];
                      final isSelected = selectedCategory == category.id;
                      final colorScheme = Theme.of(context).colorScheme;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            selectedCategory = category.id!;
                            _categoryManuallySelected = true;
                            Navigator.pop(context);
                          });
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? colorScheme.primary
                                        .withValues(alpha: 0.18)
                                    : colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                border: Border.all(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Image.asset(
                                category.icon,
                                width: 30,
                                height: 30,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                  Icons.category,
                                  size: 30,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              category.name,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                                letterSpacing: 0,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface
                                        .withValues(alpha: 0.8),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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

  void _showAccountSelector() {
    FocusScope.of(context).unfocus();
    final accounts = accountMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                child: Text(
                  'Select Account',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: accounts.length,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    final isSelected = selectedAccount == account.id;
                    return ListTile(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          selectedAccount = account.id!;
                        });
                        Navigator.pop(context);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        getAccountIcon(account.id!),
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      title: Text(
                        account.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: colorScheme.primary)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Cashew-style loan sheet: mark this transaction as money lent or
  /// borrowed, with the person's name. Saving then also creates a matching
  /// entry in the Debt Tracker.
  void _showLoanOptions() {
    FocusScope.of(context).unfocus();
    _LoanKind? pendingKind = _loanKind;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final colorScheme = Theme.of(ctx).colorScheme;

          Widget option({
            required _LoanKind? kind,
            required IconData icon,
            required String title,
            required String subtitle,
          }) {
            final selected = pendingKind == kind;
            return ListTile(
              onTap: () {
                HapticFeedback.selectionClick();
                setSheetState(() => pendingKind = kind);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(
                icon,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              title: Text(
                title,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    ),
              ),
              subtitle: Text(
                subtitle,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
              ),
              trailing: selected
                  ? Icon(Icons.check_circle, color: colorScheme.primary)
                  : null,
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text('Loan', style: AppTextStyles.h3),
                    ),
                    const SizedBox(height: 12),
                    option(
                      kind: null,
                      icon: Icons.block_outlined,
                      title: 'Not a loan',
                      subtitle: 'Just a regular transaction',
                    ),
                    option(
                      kind: _LoanKind.lent,
                      icon: Icons.call_made_rounded,
                      title: 'I lent money',
                      subtitle: 'Someone owes me · tracked in Debt Tracker',
                    ),
                    option(
                      kind: _LoanKind.borrowed,
                      icon: Icons.call_received_rounded,
                      title: 'I borrowed money',
                      subtitle: 'I owe someone · tracked in Debt Tracker',
                    ),
                    if (pendingKind != null) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _loanPersonController,
                        style: AppTextStyles.bodyMedium,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: pendingKind == _LoanKind.lent
                              ? 'Who owes you?'
                              : 'Who did you borrow from?',
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: context.appBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _loanKind = pendingKind;
                            if (_loanKind == _LoanKind.lent) {
                              // Lending is money going out.
                              _isExpense = true;
                            } else if (_loanKind == _LoanKind.borrowed) {
                              // Borrowing is money coming in.
                              _isExpense = false;
                            }
                            _fetchAndMapCategories(
                                Provider.of<CategoryProvider>(context,
                                    listen: false));
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Done', style: AppTextStyles.button),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReceiptOptions() {
    FocusScope.of(context).unfocus();
    final hasReceipt = _receiptImagePath != null;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (hasReceipt) ...[
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View receipt'),
                onTap: () {
                  Navigator.pop(ctx);
                  _viewReceipt();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.negative),
                title: const Text('Remove receipt'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _receiptImagePath = null;
                    _receiptRawText = null;
                    _receiptId = null;
                  });
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('Scan receipt'),
                onTap: () {
                  Navigator.pop(ctx);
                  _scanReceipt();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Upload photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _uploadReceipt();
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ==================== Save ====================

  Future<void> _saveData(BuildContext context) async {
    final amount = _evaluateExpression(_amountExpression) ?? 0;
    if (amount <= 0) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount'),
          backgroundColor: AppColors.negative,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final roundedAmount = double.parse(amount.toStringAsFixed(2));

    // A loan needs to know who the other party is.
    final loanPerson = _loanPersonController.text.trim();
    if (_loanKind != null && loanPerson.isEmpty) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_loanKind == _LoanKind.lent
              ? 'Add who owes you (tap the 🤝 chip)'
              : 'Add who you borrowed from (tap the 🤝 chip)'),
          backgroundColor: AppColors.negative,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    String id = _transaction?.id ?? newId();

    // Save receipt if we have a new one
    String? receiptIdToSave = _receiptId;
    if (_receiptImagePath != null && _receiptId == null) {
      final receiptDbHelper = ReceiptDBHelper();
      final newReceipt = Receipt(
        id: newId(),
        transactionId: id,
        imagePath: _receiptImagePath!,
        extractedText: _receiptRawText,
        createdOn: DateTime.now(),
      );
      await receiptDbHelper.insertReceipt(newReceipt);
      receiptIdToSave = newReceipt.id;
    }

    final existingTransaction = _transaction;
    final newTransaction = existingTransaction == null
        ? Transaction.createNew(
            id: id,
            title: _titleController.text,
            amount: roundedAmount,
            categoryId: selectedCategory,
            accountId: selectedAccount,
            date: _selectedDate,
            isExpense: _isExpense,
            isRecurring: _isRecurring,
            receiptId: receiptIdToSave,
          )
        : Transaction(
            id: id,
            title: _titleController.text,
            amount: roundedAmount,
            categoryId: selectedCategory,
            accountId: selectedAccount,
            date: _selectedDate,
            createdOn: existingTransaction.createdOn,
            modifiedOn: DateTime.now(),
            isExpense: _isExpense,
            isRecurring: _isRecurring,
            recurrenceId:
                _isRecurring ? (existingTransaction.recurrenceId ?? id) : null,
            receiptId: receiptIdToSave,
          );

    if (!context.mounted) return;

    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    // Captured before pop — the debt is created after the screen closes.
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final isUpdate = _transaction?.id != null;
    final route = ModalRoute.of(context);

    HapticFeedback.lightImpact();

    // Pop first so the close animation starts instantly. Persist once the
    // transition has finished — the provider's notifyListeners() rebuilds
    // every alive tab screen, which janks the animation if it lands
    // mid-flight.
    Navigator.of(context).pop();
    await route?.completed;

    if (isUpdate) {
      await transactionProvider.updateTransaction(newTransaction);
    } else {
      await transactionProvider.addTransaction(newTransaction);
    }

    // Cashew-style loan: mirror the transaction into the Debt Tracker.
    if (!isUpdate && _loanKind != null && loanPerson.isNotEmpty) {
      final note = _titleController.text.trim();
      await debtProvider.addDebt(Debt.createNew(
        id: newId(),
        title: note.isNotEmpty
            ? note
            : (_loanKind == _LoanKind.lent
                ? 'Lent to $loanPerson'
                : 'Borrowed from $loanPerson'),
        amount: roundedAmount,
        debtorName: loanPerson,
        // Borrowed = money I owe (liability); lent = owed to me.
        isLiability: _loanKind == _LoanKind.borrowed,
        transactionId: id,
      ));
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: context.appSurface,
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 24),
              const SizedBox(width: AppDimensions.spacing8),
              Text("Delete Transaction", style: AppTextStyles.h3),
            ],
          ),
          content: Text(
            _transaction!.isRecurring
                ? "Do you want to delete only this transaction, or stop the recurring series?"
                : "Are you sure you want to delete this transaction?",
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
            if (_transaction!.isRecurring)
              TextButton(
                onPressed: () async {
                  final transactionProvider = Provider.of<TransactionProvider>(
                    context,
                    listen: false,
                  );
                  final transaction = _transaction!;
                  // Close dialog + form first, mutate after the
                  // transition so the rebuild doesn't jank it.
                  final formRoute = ModalRoute.of(this.context);
                  Navigator.pop(context);
                  Navigator.pop(this.context);
                  await formRoute?.completed;
                  await transactionProvider.stopRecurringPayment(transaction);
                },
                child: Text(
                  "Stop Recurring",
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () async {
                final transactionProvider = Provider.of<TransactionProvider>(
                  context,
                  listen: false,
                );
                final transactionId = _transaction!.id;
                // Close dialog + form first, mutate after the
                // transition so the rebuild doesn't jank it.
                final formRoute = ModalRoute.of(this.context);
                Navigator.pop(context);
                Navigator.pop(this.context);
                await formRoute?.completed;
                await transactionProvider.deleteTransaction(transactionId);
              },
              child: Text(
                _transaction!.isRecurring ? "Delete This" : "Delete",
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditingNote = _noteFocusNode.hasFocus;
    return Scaffold(
      backgroundColor: context.appBackground,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        title: Text(
          _transaction?.id == null ? 'Add Transaction' : 'Edit Transaction',
          style: AppTextStyles.h3,
        ),
        centerTitle: true,
        actions: [
          if (_transaction?.id != null)
            IconButton(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _buildTypeToggle(),
              ),
              // Amount + note vertically centered in the free space, so the
              // screen has no dead zone regardless of device height.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisAlignment: isEditingNote
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            SizedBox(height: isEditingNote ? 24 : 0),
                            _buildAmountDisplay(),
                            _buildNoteField(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (!isEditingNote) ...[
                // Chips: category / account / date / extras
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildCategoryChip()),
                          const SizedBox(width: 8),
                          Expanded(child: _buildAccountChip()),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildDateChip()),
                          const SizedBox(width: 8),
                          _buildIconChip(
                            icon: Icons.repeat_rounded,
                            active: _isRecurring,
                            tooltip: 'Repeat monthly',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _isRecurring = !_isRecurring);
                            },
                          ),
                          const SizedBox(width: 8),
                          // Loan marker only when creating — editing an
                          // existing transaction shouldn't spawn new debts.
                          if (_transaction == null) ...[
                            _buildIconChip(
                              icon: Icons.handshake_outlined,
                              active: _loanKind != null,
                              tooltip: 'Loan (lent / borrowed)',
                              onTap: _showLoanOptions,
                            ),
                            const SizedBox(width: 8),
                          ],
                          _buildIconChip(
                            icon: _receiptImagePath != null
                                ? Icons.receipt_long
                                : Icons.receipt_long_outlined,
                            active: _receiptImagePath != null,
                            tooltip: 'Receipt',
                            onTap: _showReceiptOptions,
                          ),
                        ],
                      ),
                      // Loan summary caption, only when the marker is set.
                      if (_loanKind != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _loanKind == _LoanKind.lent
                                  ? '🤝 Lent to ${_loanPersonController.text.trim().isEmpty ? 'someone' : _loanPersonController.text.trim()} · will appear in Debt Tracker'
                                  : '🤝 Borrowed from ${_loanPersonController.text.trim().isEmpty ? 'someone' : _loanPersonController.text.trim()} · will appear in Debt Tracker',
                              style: AppTextStyles.caption.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Keypad + save
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildKeyRow(const ['7', '8', '9', '÷']),
                      _buildKeyRow(const ['4', '5', '6', '×']),
                      _buildKeyRow(const ['1', '2', '3', '-']),
                      _buildKeyRow(const ['.', '0', '⌫', '+']),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_hasOperator) {
                              _onEvaluate();
                            } else {
                              _saveData(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(
                            _hasOperator
                                ? Icons.drag_handle_rounded
                                : Icons.check_rounded,
                            size: 22,
                          ),
                          label: Text(
                            _hasOperator
                                ? '='
                                : (_transaction?.id == null
                                    ? 'Save'
                                    : 'Update'),
                            style: AppTextStyles.button.copyWith(
                              color: colorScheme.onPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          _buildTypeSegment('Expense', true),
          _buildTypeSegment('Income', false),
        ],
      ),
    );
  }

  Widget _buildTypeSegment(String label, bool expenseSegment) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _isExpense == expenseSegment;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isExpense == expenseSegment) return;
          HapticFeedback.selectionClick();
          setState(() {
            _isExpense = expenseSegment;
            selectedCategory =
                expenseSegment ? defaultExpenseCat : defaultIncomeCat;
            _fetchAndMapCategories(
                Provider.of<CategoryProvider>(context, listen: false));
          });
          _maybeSuggestCategoryForTitle();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 14,
              color: selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountDisplay() {
    final settings = Provider.of<SettingsProvider>(context);
    final amountColor = _isExpense ? AppColors.negative : AppColors.positive;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_noteFocusNode.hasFocus) {
          _noteFocusNode.unfocus();
        }
      },
      onLongPress: _onClearAll,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: settings.currencySymbol,
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 26,
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' '),
                TextSpan(
                  text: _amountExpression,
                  style: AppTextStyles.h1.copyWith(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: _amountExpression == '0'
                        ? context.textSecondary.withValues(alpha: 0.4)
                        : amountColor,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _titleController,
      focusNode: _noteFocusNode,
      style: AppTextStyles.bodyMedium,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Add a note…',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: context.textSecondary.withValues(alpha: 0.5),
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
      maxLength: 100,
      buildCounter: (context,
              {required currentLength, required isFocused, maxLength}) =>
          null,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
    );
  }

  Widget _buildCategoryChip() {
    final colorScheme = Theme.of(context).colorScheme;
    return _pickerChip(
      onTap: _showCategorySelector,
      leading: Image.asset(
        getCategoryIcon(selectedCategory),
        width: 22,
        height: 22,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.category,
          size: 22,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      label: getCategoryName(selectedCategory),
    );
  }

  Widget _buildAccountChip() {
    final colorScheme = Theme.of(context).colorScheme;
    return _pickerChip(
      onTap: _showAccountSelector,
      leading: Icon(
        getAccountIcon(selectedAccount),
        size: 20,
        color: colorScheme.primary,
      ),
      label: getAccountName(selectedAccount),
    );
  }

  Widget _buildDateChip() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final selected =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    String label;
    if (selected == today) {
      label = 'Today';
    } else if (selected == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMM d, yyyy').format(_selectedDate);
    }
    if (_isRecurring) {
      label = '$label · monthly';
    }

    return _pickerChip(
      onTap: () => _selectDate(context),
      leading: Icon(
        Icons.calendar_today_rounded,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
      label: label,
    );
  }

  Widget _pickerChip({
    required VoidCallback onTap,
    required Widget leading,
    required String label,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: context.textSecondary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconChip({
    required IconData icon,
    required bool active,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? colorScheme.primary.withValues(alpha: 0.15)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.2),
                width: active ? 1.5 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: active ? colorScheme.primary : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: keys.map(_buildKey).toList(),
      ),
    );
  }

  Widget _buildKey(String key) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOperator = ['+', '-', '×', '÷'].contains(key);
    final isBackspace = key == '⌫';

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: isOperator
              ? colorScheme.primary.withValues(alpha: 0.12)
              : context.appSurfaceLight,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () {
              if (isBackspace) {
                _onBackspace();
              } else {
                _onKeyTap(key);
              }
            },
            onLongPress: isBackspace ? _onClearAll : null,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 56,
              child: Center(
                child: isBackspace
                    ? Icon(
                        Icons.backspace_outlined,
                        size: 22,
                        color: context.textSecondary,
                      )
                    : Text(
                        key,
                        style: TextStyle(
                          fontSize: isOperator ? 26 : 23,
                          fontWeight: FontWeight.w500,
                          color: isOperator
                              ? colorScheme.primary
                              : context.textPrimary,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
