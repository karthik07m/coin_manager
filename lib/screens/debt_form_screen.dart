import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/debt_provider.dart';
import '../providers/account_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../utilities/id_generator.dart';
import '../models/debt.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../widgets/calculator_field.dart';

class DebtFormScreen extends StatefulWidget {
  static const String routeName = '/debt-form';
  final String? debtId;
  final bool isLiability;

  const DebtFormScreen({
    super.key,
    this.debtId,
    this.isLiability = true,
  });

  @override
  State<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends State<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _debtorNameController;
  late TextEditingController _amountController;
  late TextEditingController _amountPaidController;
  late TextEditingController _interestRateController;
  late TextEditingController _notesController;
  late TextEditingController _recurringAmountController;

  DateTime? _dueDate;
  late bool _isLiability;
  bool _isRecurring = false;
  Debt? _existingDebt;
  bool _isLoading = true;

  // Account linking: book the loan against an account as a transaction.
  List<Account> _accounts = [];
  int? _selectedAccountId;
  bool _bookAsTransaction = true;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _debtorNameController = TextEditingController();
    _amountController = TextEditingController();
    _amountPaidController = TextEditingController(text: '0');
    _interestRateController = TextEditingController();
    _notesController = TextEditingController();
    _recurringAmountController = TextEditingController();
    _isLiability = widget.isLiability;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDebtDetails();
    });
  }

  Future<void> _loadDebtDetails() async {
    // Capture providers before any await to avoid using context across gaps.
    final accountProvider = Provider.of<AccountProvider>(context, listen: false);
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);

    // Load accounts for the "book against account" picker.
    if (!accountProvider.isLoaded) {
      await accountProvider.loadAccounts();
    }
    if (!mounted) return;
    _accounts = List<Account>.from(accountProvider.accounts);
    final defaultId = accountProvider.defaultAccount?.id;
    _selectedAccountId =
        defaultId ?? (_accounts.isNotEmpty ? _accounts.first.id : null);

    // Load categories
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    if (categoryProvider.categoryMap.isEmpty) {
      await categoryProvider.fetchAllCategories();
    }
    if (!mounted) return;

    if (widget.debtId != null) {
      _existingDebt = debtProvider.getDebtById(widget.debtId!);

      if (_existingDebt != null) {
        setState(() {
          _titleController.text = _existingDebt!.title;
          _debtorNameController.text = _existingDebt!.debtorName;
          _amountController.text = _existingDebt!.amount.toStringAsFixed(2);
          _amountPaidController.text =
              _existingDebt!.amountPaid.toStringAsFixed(2);
          _dueDate = _existingDebt!.dueDate;
          _isLiability = _existingDebt!.isLiability;
          if (_existingDebt!.interestRate != null) {
            _interestRateController.text =
                _existingDebt!.interestRate!.toStringAsFixed(2);
          }
          if (_existingDebt!.notes != null) {
            _notesController.text = _existingDebt!.notes!;
          }
          _isRecurring = _existingDebt!.isRecurring;
          if (_existingDebt!.recurringAmount != null) {
            _recurringAmountController.text =
                _existingDebt!.recurringAmount!.toStringAsFixed(2);
          }
          if (_existingDebt!.accountId != null) {
            _selectedAccountId = _existingDebt!.accountId;
          }
        });
      }
    } else {
      setState(() {
        final isTxExpense = !_isLiability;
        _selectedCategoryId = isTxExpense ? defaultExpenseCat : defaultIncomeCat;
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _debtorNameController.dispose();
    _amountController.dispose();
    _amountPaidController.dispose();
    _interestRateController.dispose();
    _notesController.dispose();
    _recurringAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2000),
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
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  String getCategoryName(int categoryId) {
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    final category = categoryProvider.categoryMap[categoryId];
    return category?.name ?? 'Category';
  }

  String getCategoryIcon(int categoryId) {
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    return categoryProvider.categoryMap[categoryId]?.icon ?? 'assets/categories/other.png';
  }

  void _showCategorySelector(
    BuildContext context,
    bool isExpense,
    int currentCategoryId,
    Function(int) onSelected,
  ) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
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
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<CategoryProvider>(
                builder: (context, categoryProvider, child) {
                  final categories = categoryProvider.categories
                      .where((c) => c.isExpense == isExpense)
                      .toList();
                  return GridView.builder(
                    padding: const EdgeInsets.all(AppDimensions.spacing16),
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
                      final isSelected = currentCategoryId == category.id;
                      final colorScheme = Theme.of(context).colorScheme;
                      return GestureDetector(
                        onTap: () {
                          onSelected(category.id!);
                          Navigator.pop(sheetContext);
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

  void _showFormError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.negative,
      ),
    );
  }



  Future<void> _saveDebt() async {
    if (!_formKey.currentState!.validate()) return;

    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      _showFormError('Please enter a valid total amount');
      return;
    }

    final amountPaidText =
        _amountPaidController.text.replaceAll(',', '').trim();
    final amountPaid =
        amountPaidText.isEmpty ? 0.0 : double.tryParse(amountPaidText);
    if (amountPaid == null || amountPaid < 0) {
      _showFormError('Please enter a valid amount paid');
      return;
    }

    if (amountPaid > amount) {
      _showFormError('Amount paid cannot be greater than total amount');
      return;
    }

    double? interestRate;
    if (_interestRateController.text.trim().isNotEmpty) {
      interestRate = double.tryParse(_interestRateController.text.trim());
      if (interestRate == null || interestRate < 0) {
        _showFormError('Please enter a valid interest rate');
        return;
      }
    }

    double? recurringAmount;
    if (_isRecurring) {
      recurringAmount = double.tryParse(
          _recurringAmountController.text.replaceAll(',', '').trim());
      if (recurringAmount == null || recurringAmount <= 0) {
        _showFormError('Please enter a valid monthly recurring amount');
        return;
      }
    }

    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final notes = _notesController.text.trim().isNotEmpty
        ? _notesController.text.trim()
        : null;

    Debt debt;
    if (_existingDebt != null) {
      // Update existing debt
      _existingDebt!.update(
        title: _titleController.text.trim(),
        amount: amount,
        amountPaid: amountPaid,
        debtorName: _debtorNameController.text.trim(),
        isLiability: _isLiability,
        dueDate: _dueDate,
        interestRate: interestRate,
        notes: notes,
        isRecurring: _isRecurring,
        recurringAmount: recurringAmount,
      );
      debt = _existingDebt!;
      await debtProvider.updateDebt(debt);
    } else {
      final title = _titleController.text.trim();
      final debtorName = _debtorNameController.text.trim();

      // Book the loan against an account as a transaction so balances reflect
      // it: lending money is money OUT (expense), borrowing is money IN
      // (income). Skipped if the user turned booking off or picked no account.
      String? loanTxnId;
      if (_bookAsTransaction && _selectedAccountId != null) {
        final txProvider =
            Provider.of<TransactionProvider>(context, listen: false);
        final isExpense = !_isLiability; // lend = expense, borrow = income
        final categoryId = _selectedCategoryId ?? (isExpense ? defaultExpenseCat : defaultIncomeCat);
        final loanTxn = Transaction.createNew(
          id: newId(),
          title: _isLiability
              ? 'Borrowed from $debtorName · $title'
              : 'Lent to $debtorName · $title',
          amount: amount,
          categoryId: categoryId,
          accountId: _selectedAccountId!,
          date: DateTime.now(),
          isExpense: isExpense,
        );
        await txProvider.addTransaction(loanTxn);
        loanTxnId = loanTxn.id;
      }

      // Create new debt
      debt = Debt.createNew(
        id: newId(),
        title: title,
        amount: amount,
        amountPaid: amountPaid,
        debtorName: debtorName,
        isLiability: _isLiability,
        dueDate: _dueDate,
        interestRate: interestRate,
        notes: notes,
        isRecurring: _isRecurring,
        recurringAmount: recurringAmount,
        transactionId: loanTxnId,
        accountId: _selectedAccountId,
      );
      await debtProvider.addDebt(debt);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _existingDebt != null
              ? 'Debt updated successfully'
              : 'Debt added successfully',
        ),
        backgroundColor: AppColors.positive,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _deleteDebt() async {
    if (_existingDebt == null) return;

    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final payments = await debtProvider.getPaymentHistory(_existingDebt!.id);
    if (!mounted) return;

    final paymentCount = payments.length;
    final linkedTxnCount =
        payments.where((p) => p.transactionId != null).length +
            (_existingDebt!.transactionId != null ? 1 : 0);
    bool deleteLinkedTransactions = linkedTxnCount > 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.appSurface,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.negative.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_forever_rounded,
                    color: AppColors.negative, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Delete Debt', style: AppTextStyles.h3),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.textPrimary,
                  ),
                  children: [
                    const TextSpan(text: 'This will permanently delete '),
                    TextSpan(
                      text: '"${_existingDebt!.title}"',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (paymentCount > 0)
                      TextSpan(
                        text:
                            ' and $paymentCount payment record${paymentCount == 1 ? '' : 's'}',
                      ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              if (linkedTxnCount > 0) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: context.appBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.textSecondary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: CheckboxListTile(
                    value: deleteLinkedTransactions,
                    onChanged: (v) => setDialogState(
                        () => deleteLinkedTransactions = v ?? true),
                    activeColor: AppColors.negative,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Also delete $linkedTxnCount linked transaction${linkedTxnCount == 1 ? '' : 's'}',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Reverses the effect on account balances',
                      style: AppTextStyles.caption.copyWith(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.negative.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Delete',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.negative,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final transactionProvider =
          Provider.of<TransactionProvider>(context, listen: false);
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      final success = await debtProvider.deleteDebt(
        _existingDebt!.id,
        transactionProvider:
            deleteLinkedTransactions ? transactionProvider : null,
      );

      if (!mounted) return;
      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('"${_existingDebt!.title}" deleted'),
            backgroundColor: AppColors.positive,
          ),
        );
      }
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: context.appBackground,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        title: Text(
          _existingDebt != null ? 'Edit Debt' : 'Add Debt',
        ),
        elevation: 0,
        actions: [
          if (_existingDebt != null)
            IconButton(
              onPressed: _deleteDebt,
              icon: const Icon(Icons.delete, color: AppColors.negative),
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Debt Type Toggle
                Container(
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(
                      color: context.textSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildTypeToggle(
                        'Money I Owe',
                        true,
                        Icons.arrow_upward,
                      ),
                      _buildTypeToggle(
                        'Owed to Me',
                        false,
                        Icons.arrow_downward,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.spacing20),

                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Car Loan, Personal Loan',
                    prefixIcon: const Icon(Icons.title),
                    filled: true,
                    fillColor: context.appSurface,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppDimensions.spacing16),

                // Debtor Name Field
                TextFormField(
                  controller: _debtorNameController,
                  decoration: InputDecoration(
                    labelText: _isLiability ? 'Lender Name' : 'Borrower Name',
                    hintText: _isLiability
                        ? 'Who did you borrow from?'
                        : 'Who borrowed from you?',
                    prefixIcon: const Icon(Icons.person),
                    filled: true,
                    fillColor: context.appSurface,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppDimensions.spacing16),

                // Total Amount Field
                Text(
                  'Total Amount',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing8),
                CalculatorTextFormField(
                  controller: _amountController,
                ),

                const SizedBox(height: AppDimensions.spacing16),

                // Amount Paid Field
                Text(
                  'Amount Paid',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing8),
                CalculatorTextFormField(
                  controller: _amountPaidController,
                ),

                const SizedBox(height: AppDimensions.spacing16),

                // Account link + book-as-transaction (new debts only).
                if (_existingDebt == null && _accounts.isNotEmpty) ...[
                  _buildAccountSection(context),
                  const SizedBox(height: AppDimensions.spacing16),
                ],

                // Due Date Field
                InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.spacing16),
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: context.appAccent,
                        ),
                        const SizedBox(width: AppDimensions.spacing12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Due Date',
                                style: AppTextStyles.caption.copyWith(
                                  color: context.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dueDate != null
                                    ? DateFormat('MMM dd, yyyy')
                                        .format(_dueDate!)
                                    : 'No due date set',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        if (_dueDate != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() {
                                _dueDate = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.spacing16),

                // Interest Rate Field (Optional)
                TextFormField(
                  controller: _interestRateController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Interest Rate % (Optional)',
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.percent),
                    filled: true,
                    fillColor: context.appSurface,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.spacing16),

                // Notes Field
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Add any additional details...',
                    prefixIcon: const Icon(Icons.notes),
                    filled: true,
                    fillColor: context.appSurface,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.spacing20),

                // Recurring Payment Section
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spacing16),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(
                      color: _isRecurring
                          ? context.appAccent.withValues(alpha: 0.3)
                          : context.textSecondary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.repeat_rounded,
                            color: _isRecurring
                                ? context.appAccent
                                : context.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Monthly Recurring Payment',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'For subscriptions, loan payments, etc.',
                                  style: AppTextStyles.caption.copyWith(
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isRecurring,
                            onChanged: (value) {
                              setState(() {
                                _isRecurring = value;
                              });
                            },
                            activeColor: context.appAccent,
                          ),
                        ],
                      ),
                      if (_isRecurring) ...[
                        const SizedBox(height: AppDimensions.spacing16),
                        Text(
                          'Monthly Amount',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacing8),
                        CalculatorTextFormField(
                          controller: _recurringAmountController,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.spacing32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _saveDebt,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.appAccent,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                      ),
                    ),
                    child: Text(
                      _existingDebt != null ? 'Update Debt' : 'Save Debt',
                      style: AppTextStyles.button,
                    ),
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    // Lending money leaves an account; borrowing adds to it.
    final effectLabel = _isLiability
        ? 'Adds the amount to this account (money received)'
        : 'Deducts the amount from this account (money lent)';
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: _bookAsTransaction
              ? context.appAccent.withValues(alpha: 0.3)
              : context.textSecondary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  color: _bookAsTransaction
                      ? context.appAccent
                      : context.textSecondary,
                  size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Record against account',
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.bold)),
                    Text(
                      _bookAsTransaction
                          ? effectLabel
                          : 'Track this debt only, without a transaction',
                      style: AppTextStyles.caption
                          .copyWith(color: context.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _bookAsTransaction,
                onChanged: (v) => setState(() => _bookAsTransaction = v),
                activeColor: context.appAccent,
              ),
            ],
          ),
          if (_bookAsTransaction) ...[
            const SizedBox(height: AppDimensions.spacing12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: context.appSurfaceLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedAccountId,
                  dropdownColor: context.appSurface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  items: _accounts
                      .map((a) => DropdownMenuItem<int>(
                            value: a.id,
                            child: Text(a.name,
                                style: AppTextStyles.bodyMedium,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedAccountId = v),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            InkWell(
              onTap: () {
                final isExpense = !_isLiability;
                _showCategorySelector(
                  context,
                  isExpense,
                  _selectedCategoryId ?? (isExpense ? defaultExpenseCat : defaultIncomeCat),
                  (catId) {
                    setState(() {
                      _selectedCategoryId = catId;
                    });
                  },
                );
              },
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.appSurfaceLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      getCategoryIcon(_selectedCategoryId ?? (!_isLiability ? defaultExpenseCat : defaultIncomeCat)),
                      width: 22,
                      height: 22,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.category_outlined,
                        size: 22,
                        color: context.appAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        getCategoryName(_selectedCategoryId ?? (!_isLiability ? defaultExpenseCat : defaultIncomeCat)),
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: context.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeToggle(String label, bool isLiabilityType, IconData icon) {
    final isSelected = _isLiability == isLiabilityType;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _isLiability = isLiabilityType;
            final isTxExpense = !_isLiability;
            _selectedCategoryId = isTxExpense ? defaultExpenseCat : defaultIncomeCat;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.spacing12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? context.appAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : context.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : context.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
