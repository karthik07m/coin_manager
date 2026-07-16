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

  void _showFormError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.negative,
      ),
    );
  }

  /// "Miscellaneous" category id of the right type for the booked loan
  /// transaction, with safe fallbacks.
  Future<int> _miscCategoryId(bool isExpense) async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    if (categoryProvider.categoryMap.isEmpty) {
      await categoryProvider.fetchAllCategories();
    }
    for (final category in categoryProvider.categoryMap.values) {
      if (category.isExpense == isExpense &&
          category.name.toLowerCase() == 'miscellaneous') {
        return category.id!;
      }
    }
    return isExpense ? defaultExpenseCat : defaultIncomeCat;
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
        final categoryId = await _miscCategoryId(isExpense);
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppColors.negative, size: 24),
            const SizedBox(width: 8),
            Text('Delete Debt', style: AppTextStyles.h3),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this debt?',
          style: AppTextStyles.bodyMedium,
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
            child: Text(
              'Delete',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.negative,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final debtProvider = Provider.of<DebtProvider>(context, listen: false);
      await debtProvider.deleteDebt(_existingDebt!.id);
      if (!mounted) return;
      Navigator.pop(context);
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
