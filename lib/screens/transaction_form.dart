import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:math_expressions/math_expressions.dart';

import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import '../utilities/page_transitions.dart';
import '../models/category.dart';
import '../models/finance_template.dart';
import '../utilities/id_generator.dart';
import '../models/debt.dart';
import '../services/debt_transaction_service.dart';
import 'debt_detail_screen.dart';
import '../models/transaction.dart';
import '../models/receipt.dart';
import '../models/account.dart';
import '../models/ai_intent.dart';
import '../services/ai_local_parser.dart';
import '../providers/debt_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';
import '../db/receipt_db_helper.dart';
import '../widgets/category_editor_sheet.dart';
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
  final FinanceTemplate? template;

  /// Transaction to edit, shown on the very first frame so the form doesn't
  /// flash an empty "Add Transaction" while it expands open. pushNamed
  /// callers pass the id as the route argument instead.
  final Transaction? transaction;
  const TransactionForm({super.key, this.template, this.transaction});

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

  // Voice entry: on-device speech run through the same offline parser the AI
  // assistant uses. It only fills the form; nothing saves until Save.
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _isListening = false;

  // Receipt data
  String? _receiptImagePath;
  String? _receiptRawText;
  String? _receiptId;

  // Loan marker (lent/borrowed) — creates a Debt Tracker entry on save.
  bool _isSaving = false;
  _LoanKind? _loanKind;
  String? _linkedDebtId;
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

    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);

    final initial = widget.transaction;
    if (initial != null) {
      _applyTransaction(initial);
      // Chips read names from these maps; use what's already loaded.
      categoryMap = categoryProvider.categoryMap;
      if (accountProvider.isLoaded) {
        accountMap = {for (var acc in accountProvider.accounts) acc.id!: acc};
      }
    }

    Future.delayed(Duration.zero, () async {
      if (!mounted) return;
      final transactionId = widget.transaction?.id ??
          ModalRoute.of(context)?.settings.arguments as String?;
      if (transactionId != null) {
        // Editing: loadTransactionDetails already fetches & maps categories
        // for this transaction's type, so don't fetch a second time (that was
        // an extra full-tree rebuild mid-transition).
        await loadTransactionDetails(transactionId);
      } else {
        // Start where the user last filed one, not on a fixed Food default.
        final lastCategory = await Provider.of<TransactionProvider>(context,
                listen: false)
            .getLastCategoryId(_isExpense);
        if (!mounted) return;
        if (lastCategory != null) selectedCategory = lastCategory;
        await _fetchAndMapCategories(categoryProvider);
        if (!mounted) return;
        final template = widget.template;
        if (template != null &&
            template.kind == FinanceTemplateKind.monthlyPayment) {
          setState(() {
            _categoryManuallySelected = true;
            _titleController.text = template.title;
            _isRecurring = true;
            for (final name in template.categoryNames) {
              final matches = categoryMap.values.where((category) =>
                  category.isExpense &&
                  category.name.toLowerCase() == name.toLowerCase());
              if (matches.isNotEmpty) {
                selectedCategory = matches.first.id!;
                break;
              }
            }
          });
        }
      }
      if (!mounted) return;
      await _loadAccounts(accountProvider);
    });
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
    if (!mounted) return;
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

  /// Switches a new entry to the category last used for the current type,
  /// unless the user has already picked one.
  Future<void> _applyLastCategory() async {
    if (_transaction != null || _categoryManuallySelected) return;
    final type = _isExpense;
    final last = await Provider.of<TransactionProvider>(context, listen: false)
        .getLastCategoryId(type);
    if (!mounted || last == null || type != _isExpense) return;
    if (_categoryManuallySelected) return;
    if (categoryMap[last]?.isExpense == type) {
      setState(() => selectedCategory = last);
    }
  }

  Future<void> _toggleVoiceEntry() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          // The engine stops itself on silence; reflect that in the UI.
          if ((status == 'notListening' || status == 'done') &&
              mounted &&
              _isListening) {
            setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (!mounted) return;
      if (!_speechReady) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Voice input unavailable — check the microphone permission.')));
        return;
      }
    }
    HapticFeedback.lightImpact();
    setState(() => _isListening = true);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      ),
      onResult: _onVoiceResult,
    );
  }

  void _onVoiceResult(SpeechRecognitionResult result) {
    // Live transcript in the note; fill the rest once the phrase is final.
    _titleController.text = result.recognizedWords;
    if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
      _applyVoiceText(result.recognizedWords);
    }
  }

  Future<void> _applyVoiceText(String words) async {
    setState(() => _isListening = false);
    final intent = AiLocalParser().tryParse(
      message: words,
      categories: categoryMap.values.toList(),
      accounts: accountMap.values.toList(),
    );
    final draft = intent?.type == AiIntentType.addTransaction
        ? intent!.transaction
        : null;
    if (draft == null) {
      // The words stay in the note; only the amount is missing.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Didn't catch an amount — type it on the keypad.")));
      return;
    }
    if (draft.isExpense != _isExpense && !_blockIfLinked()) {
      setState(() {
        _isExpense = draft.isExpense;
        _loanKind = null;
        _linkedDebtId = null;
        _loanPersonController.clear();
      });
      await _fetchAndMapCategories(
          Provider.of<CategoryProvider>(context, listen: false));
      if (!mounted) return;
    }
    setState(() {
      _amountExpression = _formatAmountForDisplay(draft.amount);
      _titleController.text = draft.title;
      _selectedDate = draft.date;
      final categoryId = draft.categoryId;
      if (categoryId != null && categoryMap[categoryId]?.isExpense == _isExpense) {
        selectedCategory = categoryId;
        _categoryManuallySelected = true;
      }
      final accountId = draft.accountId;
      if (accountId != null && accountMap.containsKey(accountId)) {
        selectedAccount = accountId;
      }
      if (draft.isRecurring) _isRecurring = true;
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
    // Already filled from the tapped row: don't re-apply the fields, or a
    // refresh landing mid-typing would overwrite the user's edit.
    var transaction = widget.transaction;
    if (transaction == null) {
      final fetched = await Provider.of<TransactionProvider>(context,
              listen: false)
          .getTransactionById(id);
      if (fetched == null || !mounted) return;
      setState(() => _applyTransaction(fetched));
      transaction = fetched;
    }
    _fetchAndMapCategories(
        Provider.of<CategoryProvider>(context, listen: false));
    final receiptId = transaction.receiptId;
    if (receiptId != null) _loadReceipt(receiptId);
  }

  /// Fills the form from [transaction]. Safe before the first frame.
  void _applyTransaction(Transaction transaction) {
    // Set first: the title listener skips suggestions while editing.
    _transaction = transaction;
    _titleController.text = transaction.title;
    _amountExpression = _formatAmountForDisplay(transaction.amount);
    selectedCategory = transaction.categoryId;
    selectedAccount = transaction.accountId;
    _categoryManuallySelected = true;
    _selectedDate = transaction.date;
    _isExpense = transaction.isExpense;
    _isRecurring = transaction.isRecurring;
    _receiptId = transaction.receiptId;
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
      PageTransitions.fadeUp(const ReceiptScanScreen()),
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
        PageTransitions.fadeUp(
          ReceiptViewerScreen(
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

  /// Non-null when editing a transaction that was booked through the Debt
  /// Tracker (a loan or a repayment). Its amount and type mirror the debt.
  DebtLink? get _existingLink => _transaction == null
      ? null
      : context.read<DebtProvider>().linkFor(_transaction!.id);

  /// Loan/repayment rows are mirrored in the Debt Tracker; changing amount
  /// or type here would silently desync the debt balance.
  bool _blockIfLinked() {
    if (_existingLink == null) return false;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'This transaction is linked to a debt. Change the amount or type from Debt Tracker.'),
    ));
    return true;
  }

  String getDebtTitle(String debtId) {
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final debt = debtProvider.getDebtById(debtId);
    return debt != null ? '"${debt.title}" (${debt.debtorName})' : 'Debt';
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
    _speech.cancel();
    _titleDebounce?.cancel();
    _noteFocusNode.dispose();
    _titleController.dispose();
    _loanPersonController.dispose();
    super.dispose();
  }

  // ==================== Keypad logic ====================

  /// True if appending to the segment currently being typed (the part after
  /// the last operator, or the whole value when there's no operator yet)
  /// would push it past [kMaxAmount]. Blocks the keystroke instead of
  /// silently producing a number the formatters can't display.
  bool _segmentWouldExceedMax(String fullValue) {
    final segment = fullValue.split(RegExp(r'[+\-×÷]')).last;
    final parsed = double.tryParse(segment);
    return parsed != null && parsed > kMaxAmount;
  }

  void _onKeyTap(String key) {
    String value = _amountExpression;
    if (value == '0') value = '';

    if (!['+', '-', '×', '÷', '.'].contains(key) &&
        _segmentWouldExceedMax(value + key)) {
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
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
        if (!value.isFinite) return null;
        // A product/sum of in-range operands can still land out of range
        // (e.g. 999,999,999,999 × 2) — clamp rather than let a huge number
        // reach the formatters as scientific notation.
        return value.clamp(-kMaxAmount, kMaxAmount);
      }
      return double.tryParse(expression)?.clamp(-kMaxAmount, kMaxAmount);
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
                      final result = await showCategoryEditorSheet(
                        context,
                        initialIsExpense: _isExpense,
                      );
                      if (result == null || !context.mounted) return;
                      final categoryProvider = Provider.of<CategoryProvider>(
                          context,
                          listen: false);
                      final now = DateTime.now().toIso8601String();
                      await categoryProvider.addCategory(Category(
                        name: result.name,
                        icon: result.icon,
                        isExpense: result.isExpense,
                        colorValue: result.color,
                        createdOn: now,
                        modifiedOn: now,
                      ));
                      await _fetchAndMapCategories(categoryProvider);
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
                    // Adapts column count to the available width instead of
                    // forcing 4 across on every device.
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 104,
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

  Future<void> _showLoanOptions() async {
    FocusScope.of(context).unfocus();
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final currencySymbol = settingsProvider.currencySymbol;

    await debtProvider.loadDebtsFromDB();
    if (!mounted) return;
    _LoanKind? pendingKind = _loanKind;
    String? pendingLinkedDebtId = _linkedDebtId;
    bool isRepaymentMode = _linkedDebtId != null;
    bool sheetIsExpense = _isExpense;
    String? personError;

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

          final activeDebts = debtProvider.debts
              .where((d) =>
                  d.getRemainingAmount() > 0.005 &&
                  d.isLiability == sheetIsExpense)
              .toList();

          if (isRepaymentMode && activeDebts.isNotEmpty) {
            if (pendingLinkedDebtId == null ||
                !activeDebts.any((d) => d.id == pendingLinkedDebtId)) {
              pendingLinkedDebtId = activeDebts.first.id;
            }
          }

          Widget option({
            required bool active,
            required bool selected,
            required VoidCallback onTap,
            required IconData icon,
            required String title,
            required String subtitle,
          }) {
            return ListTile(
              enabled: active,
              onTap: onTap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(
                icon,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurface
                        .withValues(alpha: active ? 0.6 : 0.3),
              ),
              title: Text(
                title,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: active
                          ? null
                          : colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
              ),
              subtitle: Text(
                subtitle,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface
                          .withValues(alpha: active ? 0.55 : 0.3),
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
              // Scrollable: choosing a loan type reveals a name field or a
              // debt picker, and the keyboard then takes most of the screen.
              // Without this the sheet overflows instead of scrolling.
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Center(
                        child:
                            Text('Loans & repayments', style: AppTextStyles.h3),
                      ),
                      const SizedBox(height: 12),
                      option(
                        active: true,
                        selected: pendingKind == null && !isRepaymentMode,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setSheetState(() {
                            pendingKind = null;
                            pendingLinkedDebtId = null;
                            isRepaymentMode = false;
                          });
                        },
                        icon: Icons.block_outlined,
                        title: 'Regular transaction',
                        subtitle: 'Just a regular transaction',
                      ),
                      option(
                        active: true,
                        selected: pendingKind == _LoanKind.lent,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setSheetState(() {
                            pendingKind = _LoanKind.lent;
                            sheetIsExpense = true;
                            pendingLinkedDebtId = null;
                            isRepaymentMode = false;
                            personError = null;
                          });
                        },
                        icon: Icons.call_made_rounded,
                        title: 'Lend money',
                        subtitle: 'Someone owes me · will create a new entry',
                      ),
                      option(
                        active: true,
                        selected: pendingKind == _LoanKind.borrowed,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setSheetState(() {
                            pendingKind = _LoanKind.borrowed;
                            sheetIsExpense = false;
                            pendingLinkedDebtId = null;
                            isRepaymentMode = false;
                            personError = null;
                          });
                        },
                        icon: Icons.call_received_rounded,
                        title: 'Borrow money',
                        subtitle: 'I owe someone · will create a new entry',
                      ),
                      option(
                        active: debtProvider.debts.any((d) =>
                            d.getRemainingAmount() > 0.005 &&
                            d.isLiability == true),
                        selected: isRepaymentMode && sheetIsExpense,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setSheetState(() {
                            pendingKind = null;
                            sheetIsExpense = true;
                            isRepaymentMode = true;
                            final liabilities = debtProvider.debts
                                .where((d) =>
                                    d.getRemainingAmount() > 0.005 &&
                                    d.isLiability == true)
                                .toList();
                            if (liabilities.isNotEmpty) {
                              pendingLinkedDebtId = liabilities.first.id;
                            }
                          });
                        },
                        icon: Icons.assignment_turned_in_rounded,
                        title: 'Repay existing debt',
                        subtitle: 'I am paying back money I owe',
                      ),
                      option(
                        active: debtProvider.debts.any((d) =>
                            d.getRemainingAmount() > 0.005 &&
                            d.isLiability == false),
                        selected: isRepaymentMode && !sheetIsExpense,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setSheetState(() {
                            pendingKind = null;
                            sheetIsExpense = false;
                            isRepaymentMode = true;
                            final receivables = debtProvider.debts
                                .where((d) =>
                                    d.getRemainingAmount() > 0.005 &&
                                    d.isLiability == false)
                                .toList();
                            if (receivables.isNotEmpty) {
                              pendingLinkedDebtId = receivables.first.id;
                            }
                          });
                        },
                        icon: Icons.assignment_return_rounded,
                        title: 'Collect a repayment',
                        subtitle: 'Someone is paying me back',
                      ),
                      if (pendingKind != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Person Details',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _loanPersonController,
                          style: AppTextStyles.bodyMedium,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) {
                            if (personError != null) {
                              setSheetState(() => personError = null);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: pendingKind == _LoanKind.lent
                                ? 'Who owes you?'
                                : 'Who did you borrow from?',
                            errorText: personError,
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
                      if (isRepaymentMode && activeDebts.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Select debt · includes overdue',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: activeDebts.length,
                          itemBuilder: (ctx, idx) {
                            final d = activeDebts[idx];
                            final isSelected = pendingLinkedDebtId == d.id;
                            final remaining = d.getRemainingAmount();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primary.withValues(alpha: 0.1)
                                    : context.appBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: ListTile(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setSheetState(() {
                                    pendingLinkedDebtId = d.id;
                                  });
                                },
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    sheetIsExpense
                                        ? Icons.payment_rounded
                                        : Icons.monetization_on_rounded,
                                    size: 16,
                                    color: isSelected
                                        ? colorScheme.onPrimary
                                        : colorScheme.onSurface,
                                  ),
                                ),
                                title: Text(
                                  d.title,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${d.debtorName}${d.status == DebtStatus.overdue ? ' · Overdue' : ''}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: context.textSecondary,
                                  ),
                                ),
                                trailing: Text(
                                  UtilityFunction.addCommaWithSign(remaining,
                                      currencySymbol: currencySymbol),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: sheetIsExpense
                                        ? AppColors.negative
                                        : AppColors.positive,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            // The other party is required for a loan; refuse
                            // here rather than at save time so the user sees
                            // the error next to the field.
                            if (pendingKind != null &&
                                _loanPersonController.text.trim().isEmpty) {
                              HapticFeedback.mediumImpact();
                              setSheetState(() => personError =
                                  pendingKind == _LoanKind.lent
                                      ? 'Enter who owes you'
                                      : 'Enter who you borrowed from');
                              return;
                            }
                            HapticFeedback.selectionClick();
                            setState(() {
                              _loanKind = pendingKind;
                              _linkedDebtId = pendingLinkedDebtId;
                              _isExpense = sheetIsExpense;
                              if (_loanKind != null || _linkedDebtId != null) {
                                _isRecurring = false;
                              }
                              final linkedDebt = _linkedDebtId == null
                                  ? null
                                  : debtProvider.getDebtById(_linkedDebtId!);
                              if (linkedDebt?.accountId != null &&
                                  accountMap
                                      .containsKey(linkedDebt!.accountId)) {
                                selectedAccount = linkedDebt.accountId!;
                              }
                              final categories = Provider.of<CategoryProvider>(
                                  context,
                                  listen: false);
                              selectedCategory =
                                  _loanKind != null || _linkedDebtId != null
                                      ? categories.miscCategoryId(_isExpense)
                                      : (_isExpense
                                          ? defaultExpenseCat
                                          : defaultIncomeCat);
                              _fetchAndMapCategories(categories);
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
                          child: const Text('Confirm',
                              style: AppTextStyles.button),
                        ),
                      ),
                    ],
                  ),
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
                    Icon(Icons.delete_outline, color: AppColors.negative),
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
    if (_isSaving) return;
    final amount = _evaluateExpression(_amountExpression) ?? 0;
    if (!amount.isFinite || amount < 0.005) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter an amount'),
          backgroundColor: AppColors.negative,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final roundedAmount = double.parse(amount.toStringAsFixed(2));

    if (_transaction != null &&
        (roundedAmount != _transaction!.amount ||
            _isExpense != _transaction!.isExpense ||
            _isRecurring) &&
        _blockIfLinked()) {
      return;
    }

    // A loan needs to know who the other party is.
    final loanPerson = _loanPersonController.text.trim();
    if (_loanKind != null && loanPerson.isEmpty) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_loanKind == _LoanKind.lent
              ? 'Add who owes you in Loans & repayments'
              : 'Add who you borrowed from in Loans & repayments'),
          backgroundColor: AppColors.negative,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    String? stagedReceiptId;
    bool saved = false;
    try {
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
        if (await receiptDbHelper.insertReceipt(newReceipt) == -1) {
          throw StateError('Could not save receipt');
        }
        stagedReceiptId = newReceipt.id;
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
              recurrenceId: _isRecurring
                  ? (existingTransaction.recurrenceId ?? id)
                  : null,
              receiptId: receiptIdToSave,
            );

      if (!context.mounted) return;

      final transactionProvider =
          Provider.of<TransactionProvider>(context, listen: false);
      final debtProvider = Provider.of<DebtProvider>(context, listen: false);
      final service = DebtTransactionService(
          transactions: transactionProvider, debts: debtProvider);
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      String? savedDebtId;
      if (_transaction != null) {
        await transactionProvider.updateTransaction(newTransaction);
      } else if (_loanKind != null) {
        final note = _titleController.text.trim();
        savedDebtId = await service.saveLoan(
            newTransaction,
            Debt.createNew(
              id: newId(),
              title: note.isNotEmpty
                  ? note
                  : (_loanKind == _LoanKind.lent
                      ? 'Lent to $loanPerson'
                      : 'Borrowed from $loanPerson'),
              amount: roundedAmount,
              debtorName: loanPerson,
              isLiability: _loanKind == _LoanKind.borrowed,
            ));
      } else if (_linkedDebtId != null) {
        savedDebtId =
            await service.saveRepayment(newTransaction, _linkedDebtId!);
      } else {
        await transactionProvider.addTransaction(newTransaction);
      }
      saved = true;
      if (!mounted) return;
      HapticFeedback.lightImpact();
      navigator.pop();
      if (savedDebtId != null) {
        final debtId = savedDebtId;
        messenger.showSnackBar(SnackBar(
          content: Text(_loanKind != null
              ? 'Transaction saved and added to Debt Tracker'
              : 'Transaction saved and debt balance updated'),
          action: SnackBarAction(
              label: 'View debt',
              onPressed: () {
                navigator.push(MaterialPageRoute<void>(
                    builder: (_) => DebtDetailScreen(debtId: debtId)));
              }),
        ));
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is DebtEntryException
            ? error.message
            : 'Could not save. Please try again.'),
        backgroundColor: AppColors.negative,
      ));
    } finally {
      // Keep the selected photo available when the user retries a rejected
      // entry, but remove its uncommitted receipt row.
      if (!saved && stagedReceiptId != null) {
        try {
          await ReceiptDBHelper()
              .deleteReceipt(stagedReceiptId, preserveImage: true);
        } catch (error) {
          debugPrint('Could not clean up draft receipt: $error');
        }
      }
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmDelete() {
    // Deleting a loan/repayment here would leave the debt's balance wrong;
    // Debt Tracker deletes both halves together.
    final link = _existingLink;
    if (link != null) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            'This transaction is linked to a debt. Delete it from Debt Tracker.'),
        action: SnackBarAction(
            label: 'Open',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => DebtDetailScreen(debtId: link.debtId)))),
      ));
      return;
    }
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
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.negative),
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
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.negative),
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
    return AbsorbPointer(
        absorbing: _isSaving,
        child: Scaffold(
          backgroundColor: context.appBackground,
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            backgroundColor: context.appBackground,
            elevation: 0,
            title: Text(
              _transaction?.id == null ? 'Add Transaction' : 'Edit Transaction',
            ),
            actions: [
              if (_transaction?.id != null)
                IconButton(
                  onPressed: _confirmDelete,
                  icon: Icon(Icons.delete_outline, color: AppColors.negative),
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
                            constraints: BoxConstraints(
                                minHeight: constraints.maxHeight),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildAmountDisplay(),
                                _buildNoteField(),
                                // Chips: category / account / date / extras
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                                      Row(children: [
                                        Expanded(child: _buildDateChip())
                                      ]),
                                      const SizedBox(height: 8),
                                      // Wrap rather than Row: the labelled chips fit one line
                                      // on a normal phone but reflow instead of overflowing on
                                      // narrow screens or at large text scales.
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _buildIconChip(
                                              icon: Icons.repeat_rounded,
                                              active: _isRecurring,
                                              label: 'Repeat',
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                if (_blockIfLinked()) return;
                                                if (_loanKind != null ||
                                                    _linkedDebtId != null) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            'Loans and repayments are recorded once. Choose Regular transaction to repeat.')),
                                                  );
                                                  return;
                                                }
                                                setState(() => _isRecurring =
                                                    !_isRecurring);
                                              },
                                            ),
                                            // Loan marker only when creating — editing an
                                            // existing transaction shouldn't spawn new debts.
                                            if (_transaction == null)
                                              _buildIconChip(
                                                icon: Icons.handshake_outlined,
                                                active: _loanKind != null ||
                                                    _linkedDebtId != null,
                                                label: 'Loans & repayments',
                                                onTap: _showLoanOptions,
                                              ),
                                            _buildIconChip(
                                              icon: _receiptImagePath != null
                                                  ? Icons.receipt_long
                                                  : Icons.receipt_long_outlined,
                                              active: _receiptImagePath != null,
                                              label: 'Receipt',
                                              onTap: _showReceiptOptions,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_loanKind != null ||
                                          _linkedDebtId != null)
                                        _buildDebtSummary()
                                      else if (_transaction != null)
                                        _buildExistingLinkCard(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Keep the keypad accessible while the entry details scroll.
                  ...[
                    // Keypad + save
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
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
                            child: ElevatedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () {
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Only the Save/Update state gets a check icon —
                                  // showing an icon next to the literal "=" text
                                  // for the evaluate state doubled up as "= =".
                                  if (!_hasOperator) ...[
                                    const Icon(Icons.check_rounded, size: 22),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    _isSaving
                                        ? 'Saving…'
                                        : _hasOperator
                                            ? '='
                                            : (_transaction?.id == null
                                                ? 'Save'
                                                : 'Update'),
                                    style: AppTextStyles.button.copyWith(
                                      color: colorScheme.onPrimary,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
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
        ));
  }

  Widget _buildExistingLinkCard() {
    final link =
        context.watch<DebtProvider>().linkFor(_transaction!.id);
    if (link == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.handshake_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link.label,
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w600)),
                Text('Linked to Debt Tracker · amount and type follow the debt',
                    style: AppTextStyles.caption),
              ]),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => DebtDetailScreen(debtId: link.debtId))),
          child: const Text('View'),
        ),
      ]),
    );
  }

  Widget _buildDebtSummary() {
    final debt = _linkedDebtId == null
        ? null
        : context.watch<DebtProvider>().getDebtById(_linkedDebtId!);
    final symbol = context.watch<SettingsProvider>().currencySymbol;
    final person = _loanPersonController.text.trim();
    final remaining = debt?.getRemainingAmount();
    final title = debt != null
        ? '${_isExpense ? 'Repay' : 'Collect from'} ${debt.debtorName}'
        : _loanKind == _LoanKind.lent
            ? 'Lending to ${person.isEmpty ? 'someone' : person}'
            : 'Borrowing from ${person.isEmpty ? 'someone' : person}';
    final detail = remaining == null
        ? 'Creates a linked debt in Debt Tracker.'
        : 'Remaining: ${UtilityFunction.addCommaWithSign(remaining, currencySymbol: symbol)}';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.handshake_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 4),
        Text(detail, style: AppTextStyles.caption),
        if (remaining != null)
          TextButton(
            onPressed: () => setState(() {
              _amountExpression = _formatAmountForDisplay(remaining);
            }),
            child: const Text('Use full remaining amount'),
          ),
      ]),
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
          if (_isExpense == expenseSegment || _blockIfLinked()) return;
          HapticFeedback.selectionClick();
          setState(() {
            _isExpense = expenseSegment;
            _loanKind = null;
            _linkedDebtId = null;
            _loanPersonController.clear();
            selectedCategory =
                expenseSegment ? defaultExpenseCat : defaultIncomeCat;
            _fetchAndMapCategories(
                Provider.of<CategoryProvider>(context, listen: false));
          });
          _applyLastCategory();
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
    // Voice only for new entries, so it can't overwrite a saved transaction.
    final showMic = _transaction == null;
    return Row(
      children: [
        // Balances the mic so the note stays centred under the amount.
        if (showMic) const SizedBox(width: 48),
        Expanded(
          child: TextField(
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
          ),
        ),
        if (showMic)
          IconButton(
            onPressed: _toggleVoiceEntry,
            tooltip: _isListening
                ? 'Stop listening'
                : 'Say it, e.g. "coffee 150"',
            icon: Icon(
              _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: _isListening ? AppColors.negative : context.appAccent,
              semanticLabel: _isListening ? 'Stop listening' : 'Add by voice',
            ),
          ),
      ],
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

  /// A toggle chip for the secondary transaction attributes (repeat, loan,
  /// receipt).
  ///
  /// These carry a visible text label rather than relying on a tooltip:
  /// tooltips only fire on long-press on touch devices, which nobody performs
  /// on an icon they don't already recognise. Two of these three controls
  /// permanently change the user's data — repeating turns one entry into an
  /// open-ended monthly series, and a loan creates a debt record — so the
  /// label is what makes the consequence discoverable before the first tap.
  Widget _buildIconChip({
    required IconData icon,
    required bool active,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: active
          ? colorScheme.primary.withValues(alpha: 0.15)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.2),
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? colorScheme.primary : context.textSecondary,
              ),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: active ? colorScheme.primary : context.textPrimary,
                ),
              )),
            ],
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
