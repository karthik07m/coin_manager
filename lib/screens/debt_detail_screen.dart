import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utilities/page_transitions.dart';
import '../providers/account_provider.dart';
import '../utilities/id_generator.dart';
import '../providers/category_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/account.dart';
import '../models/debt.dart';
import '../models/debt_payment.dart';
import '../models/transaction.dart';
import '../utilities/constants.dart';
import '../utilities/functions.dart';
import '../utilities/theme_helper.dart';
import '../widgets/calculator_field.dart';
import '../db/transaction_db_helper.dart';
import 'debt_form_screen.dart';

class DebtDetailScreen extends StatefulWidget {
  static const String routeName = '/debt-detail';
  final String debtId;

  const DebtDetailScreen({super.key, required this.debtId});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  List<DebtPayment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    // The balance may have changed outside this provider (a linked
    // transaction deleted from the list reverses its payment in the DB), so
    // refresh the cached debts alongside the history.
    await debtProvider.loadDebtsFromDB();
    final payments = await debtProvider.getPaymentHistory(widget.debtId);
    if (!mounted) return;
    setState(() {
      _payments = payments;
      _isLoading = false;
    });
  }

  String getCategoryName(int categoryId) {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final category = categoryProvider.categoryMap[categoryId];
    return category?.name ?? 'Category';
  }

  String getCategoryIcon(int categoryId) {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    return categoryProvider.categoryMap[categoryId]?.icon ??
        'assets/categories/other.png';
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

  /// Category for auto-created settlement transactions: "Miscellaneous" of
  /// the right type, with safe fallbacks if the user renamed/deleted it.
  Future<int> _miscCategoryId(bool isExpense) async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    if (categoryProvider.categoryMap.isEmpty) {
      await categoryProvider.fetchAllCategories();
    }
    return categoryProvider.miscCategoryId(isExpense);
  }

  /// Money comes back to (or leaves from) the account the loan was booked
  /// against; otherwise the default account.
  static int _settlementAccountId(Debt debt, List<Account> accounts,
      {int? fallback}) {
    if (accounts.any((a) => a.id == debt.accountId)) return debt.accountId!;
    if (accounts.any((a) => a.id == fallback)) return fallback!;
    return accounts.isNotEmpty ? accounts.first.id! : 1;
  }

  /// Creates the spending/income transaction for a settlement and returns
  /// its id, so the debt payment can link back to it.
  Future<String> _createSettlementTransaction(
    Debt debt,
    double amount,
    DateTime date, {
    int accountId = 1,
    int? categoryId,
  }) async {
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    // Paying off my debt = money out; getting repaid = money in.
    final isExpense = debt.isLiability;
    final catId = categoryId ?? await _miscCategoryId(isExpense);

    final transaction = Transaction.createNew(
      id: newId(),
      title: isExpense
          ? 'Paid ${debt.debtorName} · ${debt.title}'
          : 'Repayment from ${debt.debtorName} · ${debt.title}',
      amount: amount,
      categoryId: catId,
      accountId: accountId,
      date: date,
      isExpense: isExpense,
    );
    await transactionProvider.addTransaction(transaction);
    return transaction.id;
  }

  IconData _accountIcon(Account account) {
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

  /// Records [t] (an already-existing transaction) as a payment toward [debt]
  /// — no new transaction is created, we just link it and reduce the balance.
  Future<void> _linkTransactionAsPayment(
      Debt debt, Transaction t, BuildContext sheetCtx) async {
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final sheetNavigator = Navigator.of(sheetCtx);
    final payment = DebtPayment.createNew(
      id: newId(),
      debtId: debt.id,
      amount: t.amount,
      paymentDate: t.date,
      notes: t.title.trim().isEmpty ? 'Linked transaction' : t.title.trim(),
      transactionId: t.id,
    );
    final ok = await debtProvider.recordPayment(debt.id, payment);
    if (!mounted) return;
    sheetNavigator.pop();
    if (ok) {
      await _loadPaymentHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction linked as payment')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Could not link. Check the remaining balance and whether this transaction is already linked.'),
          backgroundColor: AppColors.negative,
        ),
      );
    }
  }

  /// Picks an existing transaction to attach to this debt as a payment. Shows
  /// transactions of the matching type (expense for money I owe, income for
  /// money owed to me), newest first.
  Future<void> _showLinkTransactionSheet(Debt debt) async {
    final remaining = debt.getRemainingAmount();
    if (remaining <= 0.005) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This debt is already fully paid')),
      );
      return;
    }

    final wantExpense = debt.isLiability; // paying my debt = an expense
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final linkedIds = await debtProvider.getLinkedTransactionIds();
    final all = await TransactionDBHelper().getTransactions();
    final candidates = all
        .where((t) =>
            !t.isTransfer &&
            !t.isRecurring &&
            !linkedIds.contains(t.id) &&
            t.isExpense == wantExpense &&
            t.amount > 0 &&
            t.amount <= remaining + 0.005)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final recent = candidates.take(60).toList();

    if (!mounted) return;
    final currency =
        Provider.of<SettingsProvider>(context, listen: false).currencySymbol;
    String money(double v) =>
        UtilityFunction.formatMoney(v, symbol: currency, showDecimals: true);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Link a transaction as payment',
                      style: AppTextStyles.h3),
                  const SizedBox(height: 4),
                  Text(
                    'Toward "${debt.title}" · ${money(remaining)} remaining',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: context.textSecondary),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1, color: context.textSecondary.withValues(alpha: 0.1)),
            Flexible(
              child: recent.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        wantExpense
                            ? 'No expense transactions to link yet.'
                            : 'No income transactions to link yet.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: context.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: recent.length,
                      itemBuilder: (c, i) {
                        final t = recent[i];
                        final tooBig = t.amount > remaining + 0.005;
                        return ListTile(
                          enabled: !tooBig,
                          leading: CircleAvatar(
                            backgroundColor:
                                context.appAccent.withValues(alpha: 0.12),
                            child: Icon(Icons.receipt_long_rounded,
                                size: 18, color: context.appAccent),
                          ),
                          title: Text(
                            t.title.trim().isEmpty ? 'Transaction' : t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium,
                          ),
                          subtitle: Text(
                            DateFormat('MMM dd, yyyy').format(t.date) +
                                (tooBig ? ' · exceeds remaining' : ''),
                            style: AppTextStyles.caption.copyWith(
                              color: tooBig
                                  ? AppColors.negative
                                  : context.textSecondary,
                            ),
                          ),
                          trailing: Text(
                            money(t.amount),
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: tooBig
                                  ? context.textSecondary
                                  : context.textPrimary,
                            ),
                          ),
                          onTap: tooBig
                              ? null
                              : () => _linkTransactionAsPayment(debt, t, ctx),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _showRecordPaymentDialog(Debt debt) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    DateTime paymentDate = DateTime.now();
    bool addAsTransaction = true;

    // Capture providers before any await to avoid using context across gaps.
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    // Accounts for the settlement transaction's account picker.
    if (!accountProvider.isLoaded) {
      await accountProvider.loadAccounts();
    }
    // Load categories
    if (categoryProvider.categoryMap.isEmpty) {
      await categoryProvider.fetchAllCategories();
    }
    if (!mounted) return;
    final accounts = List<Account>.from(accountProvider.accounts)
      ..sort((a, b) => a.name.compareTo(b.name));
    int selectedAccountId = _settlementAccountId(debt, accounts,
        fallback: accountProvider.defaultAccount?.id);
    int selectedCategoryId = categoryProvider.miscCategoryId(debt.isLiability);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const SizedBox(height: 8),
                Text('Record Payment', style: AppTextStyles.h3),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Amount',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CalculatorTextFormField(
                        controller: amountController,
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Payment Date',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: paymentDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() {
                              paymentDate = picked;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: context.appBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  context.textSecondary.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  color: context.appAccent, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('MMM dd, yyyy').format(paymentDate),
                                style: AppTextStyles.bodyLarge,
                              ),
                              const Spacer(),
                              Icon(Icons.chevron_right_rounded,
                                  color: context.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Notes (Optional)',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        style: AppTextStyles.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Add a note...',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(
                            color: context.textSecondary.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor: context.appBackground,
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color:
                                  context.textSecondary.withValues(alpha: 0.1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color:
                                  context.textSecondary.withValues(alpha: 0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: context.appAccent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),

                      // Mirror the settlement into transactions (Cashew-style)
                      Container(
                        decoration: BoxDecoration(
                          color: context.appBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.textSecondary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: SwitchListTile(
                          value: addAsTransaction,
                          onChanged: (v) =>
                              setModalState(() => addAsTransaction = v),
                          activeColor: context.appAccent,
                          title: Text(
                            'Add to transactions',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            debt.isLiability
                                ? 'Records an expense to ${debt.debtorName}'
                                : 'Records income from ${debt.debtorName}',
                            style: AppTextStyles.caption.copyWith(
                              color: context.textSecondary,
                              fontSize: 11,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),

                      // Which account the settlement hits.
                      if (addAsTransaction && accounts.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          debt.isLiability ? 'Pay from' : 'Receive into',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: accounts.map((account) {
                            final isSelected = selectedAccountId == account.id;
                            final colorScheme = Theme.of(context).colorScheme;
                            return GestureDetector(
                              onTap: () => setModalState(
                                  () => selectedAccountId = account.id!),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.primary
                                          .withValues(alpha: 0.12)
                                      : context.appBackground,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : context.textSecondary
                                            .withValues(alpha: 0.15),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _accountIcon(account),
                                      size: 16,
                                      color: isSelected
                                          ? colorScheme.primary
                                          : context.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      account.name,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 13,
                                        color: isSelected
                                            ? colorScheme.primary
                                            : context.textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (addAsTransaction) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Category',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () {
                            final isTxExpense = debt.isLiability;
                            _showCategorySelector(
                              context,
                              isTxExpense,
                              selectedCategoryId,
                              (catId) {
                                setModalState(() {
                                  selectedCategoryId = catId;
                                });
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: context.appBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: context.textSecondary
                                    .withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Image.asset(
                                  getCategoryIcon(selectedCategoryId),
                                  width: 22,
                                  height: 22,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                    Icons.category_outlined,
                                    size: 22,
                                    color: context.appAccent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    getCategoryName(selectedCategoryId),
                                    style: AppTextStyles.bodyLarge,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: context.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: context.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                final amountText =
                                    amountController.text.replaceAll(',', '');
                                if (amountText.isEmpty) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text('Please enter an amount'),
                                      backgroundColor: AppColors.negative,
                                    ),
                                  );
                                  return;
                                }

                                final amount = double.tryParse(amountText);
                                if (amount == null || amount <= 0) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Please enter a valid amount'),
                                      backgroundColor: AppColors.negative,
                                    ),
                                  );
                                  return;
                                }

                                final remaining = debt.getRemainingAmount();
                                final currencySymbol =
                                    Provider.of<SettingsProvider>(context,
                                            listen: false)
                                        .currencySymbol;
                                if (amount > remaining) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Amount cannot exceed remaining balance of ${UtilityFunction.addCommaWithSign(remaining, currencySymbol: currencySymbol)}'),
                                      backgroundColor: AppColors.negative,
                                    ),
                                  );
                                  return;
                                }

                                final debtProvider = Provider.of<DebtProvider>(
                                    this.context,
                                    listen: false);
                                final transactionProvider =
                                    Provider.of<TransactionProvider>(
                                        this.context,
                                        listen: false);
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(context);

                                // Optionally mirror into transactions first,
                                // so the payment can link back to it.
                                String? settlementTransactionId;
                                if (addAsTransaction) {
                                  settlementTransactionId =
                                      await _createSettlementTransaction(
                                    debt,
                                    amount,
                                    paymentDate,
                                    accountId: selectedAccountId,
                                    categoryId: selectedCategoryId,
                                  );
                                }

                                final payment = DebtPayment.createNew(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  debtId: debt.id,
                                  amount: amount,
                                  paymentDate: paymentDate,
                                  notes: notesController.text.isNotEmpty
                                      ? notesController.text
                                      : null,
                                  transactionId: settlementTransactionId,
                                );

                                final success = await debtProvider
                                    .recordPayment(debt.id, payment);

                                // Roll back the settlement transaction if the
                                // payment was rejected, so we never leave a
                                // spend record for a payment that didn't apply.
                                if (!success &&
                                    settlementTransactionId != null) {
                                  await transactionProvider.deleteTransaction(
                                      settlementTransactionId);
                                }

                                if (!context.mounted) return;
                                navigator.pop();
                                if (success) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Payment recorded successfully'),
                                      backgroundColor: AppColors.positive,
                                    ),
                                  );
                                  _loadPaymentHistory();
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to record payment'),
                                      backgroundColor: AppColors.negative,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.appAccent,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Record Payment',
                                style: AppTextStyles.button,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markAsPaid() async {
    // Capture providers before any await to avoid using context across gaps.
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);

    if (!accountProvider.isLoaded) {
      await accountProvider.loadAccounts();
    }
    if (categoryProvider.categoryMap.isEmpty) {
      await categoryProvider.fetchAllCategories();
    }
    if (!mounted) return;

    final accounts = List<Account>.from(accountProvider.accounts)
      ..sort((a, b) => a.name.compareTo(b.name));
    final debt = debtProvider.getDebtById(widget.debtId);
    if (debt == null) return;

    int selectedAccountId = _settlementAccountId(debt, accounts,
        fallback: accountProvider.defaultAccount?.id);
    int selectedCategoryId = categoryProvider.miscCategoryId(debt.isLiability);
    bool addAsTransaction = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.appSurface,
          title: Text('Mark as Paid', style: AppTextStyles.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to mark this debt as fully paid?',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: addAsTransaction,
                onChanged: (v) =>
                    setDialogState(() => addAsTransaction = v ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: context.appAccent,
                title: Text(
                  'Add the final payment to transactions',
                  style: AppTextStyles.bodySmall,
                ),
              ),
              if (addAsTransaction) ...[
                const SizedBox(height: 12),
                Text(
                  debt.isLiability ? 'Pay from' : 'Receive into',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: context.appBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.textSecondary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedAccountId,
                      dropdownColor: context.appSurface,
                      items: accounts
                          .map((a) => DropdownMenuItem<int>(
                                value: a.id,
                                child: Text(a.name,
                                    style: AppTextStyles.bodyMedium),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedAccountId = v);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Category',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    final isTxExpense = debt.isLiability;
                    _showCategorySelector(
                      context,
                      isTxExpense,
                      selectedCategoryId,
                      (catId) {
                        setDialogState(() {
                          selectedCategoryId = catId;
                        });
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.appBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.textSecondary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          getCategoryIcon(selectedCategoryId),
                          width: 20,
                          height: 20,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.category_outlined,
                            size: 20,
                            color: context.appAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            getCategoryName(selectedCategoryId),
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.textSecondary,
                          size: 18,
                        ),
                      ],
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
              child: Text(
                'Mark as Paid',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.positive,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final transactionProvider =
          Provider.of<TransactionProvider>(context, listen: false);

      // Mirror the final payment into transactions before settling, so the
      // payment record can link back to it.
      String? settlementTransactionId;
      final remaining = debt.getRemainingAmount();
      if (addAsTransaction && remaining > 0) {
        settlementTransactionId = await _createSettlementTransaction(
          debt,
          remaining,
          DateTime.now(),
          accountId: selectedAccountId,
          categoryId: selectedCategoryId,
        );
      }
      if (!mounted) return;

      final success = await debtProvider.markAsPaid(widget.debtId,
          transactionId: settlementTransactionId);

      // Roll back the settlement transaction if settling failed.
      if (!success && settlementTransactionId != null) {
        await transactionProvider.deleteTransaction(settlementTransactionId);
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debt marked as paid'),
            backgroundColor: AppColors.positive,
          ),
        );
        _loadPaymentHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as paid'),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    }
  }

  Future<void> _deleteDebt() async {
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final debt = debtProvider.getDebtById(widget.debtId);
    if (debt == null) return;

    final paymentCount = _payments.length;
    final linkedTxnCount =
        _payments.where((p) => p.transactionId != null).length +
            (debt.transactionId != null ? 1 : 0);

    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final currencySymbol = settingsProvider.currencySymbol;

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
                child: Icon(Icons.delete_forever_rounded,
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
                      text: '"${debt.title}"',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Impact summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.negative.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.negative.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What will be deleted:',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.negative,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _impactRow(Icons.receipt_long_rounded,
                        '$paymentCount payment record${paymentCount == 1 ? '' : 's'}'),
                    const SizedBox(height: 4),
                    _impactRow(Icons.account_balance_wallet_rounded,
                        'Remaining: ${UtilityFunction.addCommaWithSign(debt.getRemainingAmount(), currencySymbol: currencySymbol)}'),
                    if (linkedTxnCount > 0) ...[
                      const SizedBox(height: 4),
                      _impactRow(Icons.swap_horiz_rounded,
                          '$linkedTxnCount linked transaction${linkedTxnCount == 1 ? '' : 's'}'),
                    ],
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Also delete linked transactions',
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
        widget.debtId,
        transactionProvider:
            deleteLinkedTransactions ? transactionProvider : null,
      );

      if (!mounted) return;
      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('"${debt.title}" deleted'),
            backgroundColor: AppColors.positive,
          ),
        );
        navigator.pop();
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete debt'),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeletePayment(
      DebtPayment payment, String currencySymbol) async {
    final hasLinkedTxn = payment.transactionId != null;
    bool deleteLinkedTransaction = hasLinkedTxn;

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
                child: Icon(Icons.remove_circle_outline_rounded,
                    color: AppColors.negative, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Delete Payment', style: AppTextStyles.h3),
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
                    const TextSpan(text: 'This will remove the '),
                    TextSpan(
                      text: UtilityFunction.addCommaWithSign(payment.amount,
                          currencySymbol: currencySymbol),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                        text:
                            ' payment and add the amount back to the debt balance.'),
                  ],
                ),
              ),
              if (hasLinkedTxn) ...[
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
                    value: deleteLinkedTransaction,
                    onChanged: (v) => setDialogState(
                        () => deleteLinkedTransaction = v ?? true),
                    activeColor: AppColors.negative,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Also delete linked transaction',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Reverses the effect on account balance',
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
      final debtProvider = Provider.of<DebtProvider>(context, listen: false);
      final transactionProvider =
          Provider.of<TransactionProvider>(context, listen: false);
      final messenger = ScaffoldMessenger.of(context);

      final success = await debtProvider.deletePayment(
        payment.id,
        transactionProvider:
            deleteLinkedTransaction ? transactionProvider : null,
      );

      if (!mounted) return;
      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
                'Payment of ${UtilityFunction.addCommaWithSign(payment.amount, currencySymbol: currencySymbol)} deleted'),
            backgroundColor: AppColors.positive,
          ),
        );
        _loadPaymentHistory();
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete payment'),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    }
  }

  Widget _impactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.negative.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: context.textPrimary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        title: const Text('Debt Details'),
        elevation: 0,
        actions: [
          Consumer<DebtProvider>(
            builder: (context, debtProvider, child) {
              final debt = debtProvider.getDebtById(widget.debtId);
              if (debt == null) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageTransitions.fadeUp(
                          DebtFormScreen(
                            debtId: debt.id,
                            isLiability: debt.isLiability,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    onPressed: _deleteDebt,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppColors.negative,
                    tooltip: 'Delete debt',
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer2<DebtProvider, SettingsProvider>(
        builder: (context, debtProvider, settingsProvider, child) {
          final debt = debtProvider.getDebtById(widget.debtId);
          final currencySymbol = settingsProvider.currencySymbol;

          if (debt == null) {
            return const Center(
              child: Text('Debt not found'),
            );
          }

          final remaining = debt.getRemainingAmount();
          final progress = debt.getProgressPercentage();

          Color statusColor;
          if (debt.status == DebtStatus.paid) {
            statusColor = AppColors.positive;
          } else if (debt.status == DebtStatus.overdue) {
            statusColor = AppColors.negative;
          } else if (progress >= 80) {
            statusColor = AppColors.warning;
          } else {
            statusColor = context.appAccent;
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor,
                          statusColor.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                debt.isLiability
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    debt.title,
                                    style: AppTextStyles.h2.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    debt.debtorName,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Remaining Balance',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          UtilityFunction.addCommaWithSign(remaining,
                              currencySymbol: currencySymbol),
                          style: AppTextStyles.h1.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 36,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'of ${UtilityFunction.addCommaWithSign(debt.amount, currencySymbol: currencySymbol)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${progress.toStringAsFixed(0)}% paid',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Details Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Details',
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (debt.dueDate != null)
                          _buildDetailRow(
                            'Due Date',
                            _dueRelativeLabel(debt) != null
                                ? '${DateFormat('MMM dd, yyyy').format(debt.dueDate!)} (${_dueRelativeLabel(debt)})'
                                : DateFormat('MMM dd, yyyy')
                                    .format(debt.dueDate!),
                            Icons.calendar_today,
                          ),
                        _buildDetailRow(
                          'Status',
                          '${debt.status.name[0].toUpperCase()}${debt.status.name.substring(1)}',
                          Icons.info_outline,
                        ),
                        if (debt.interestRate != null)
                          _buildDetailRow(
                            'Interest Rate',
                            '${debt.interestRate}%',
                            Icons.percent,
                          ),
                        if (debt.isRecurring) ...[
                          const Divider(height: 24),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      context.appAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.repeat_rounded,
                                      size: 16,
                                      color: context.appAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Monthly recurring',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: context.appAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (debt.recurringAmount != null) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Recurring Amount',
                              UtilityFunction.addCommaWithSign(
                                  debt.recurringAmount!,
                                  currencySymbol: currencySymbol),
                              Icons.payments,
                            ),
                          ],
                        ],
                        if (debt.notes != null) ...[
                          const Divider(height: 24),
                          Text(
                            'Notes',
                            style: AppTextStyles.caption.copyWith(
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            debt.notes!,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment History
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment History',
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_payments.length} ${_payments.length == 1 ? 'payment' : 'payments'}',
                        style: AppTextStyles.caption.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_payments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 48,
                              color:
                                  context.textSecondary.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No payments recorded yet',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _payments.length,
                      itemBuilder: (context, index) {
                        final payment = _payments[index];
                        return Dismissible(
                          key: Key(payment.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            _confirmDeletePayment(payment, currencySymbol);
                            return false; // Dialog handles the delete
                          },
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.negative,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          child: GestureDetector(
                            onLongPress: () =>
                                _confirmDeletePayment(payment, currencySymbol),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.appSurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.positive
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.check_circle,
                                      color: AppColors.positive,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          UtilityFunction.addCommaWithSign(
                                              payment.amount,
                                              currencySymbol: currencySymbol),
                                          style:
                                              AppTextStyles.bodyLarge.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              DateFormat('MMM dd, yyyy')
                                                  .format(payment.paymentDate),
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                color: context.textSecondary,
                                              ),
                                            ),
                                            if (payment.notes != null) ...[
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  '• ${payment.notes}',
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                    color:
                                                        context.textSecondary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                            if (payment.transactionId !=
                                                null) ...[
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.link_rounded,
                                                size: 13,
                                                color: context.appAccent,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                'in transactions',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                  color: context.appAccent,
                                                  fontSize: 10,
                                                  letterSpacing: 0,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Consumer<DebtProvider>(
        builder: (context, debtProvider, child) {
          final debt = debtProvider.getDebtById(widget.debtId);
          if (debt == null || debt.status == DebtStatus.paid) {
            return const SizedBox.shrink();
          }

          return Container(
            padding: EdgeInsets.only(
              left: AppDimensions.spacing16,
              right: AppDimensions.spacing16,
              top: AppDimensions.spacing8,
              bottom: MediaQuery.of(context).padding.bottom +
                  AppDimensions.spacing8,
            ),
            decoration: BoxDecoration(
              color: context.appSurface,
              border: Border(
                top: BorderSide(
                  color: context.textSecondary.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _showRecordPaymentDialog(debt),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appAccent,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.payment_rounded, size: 18),
                      label: const Text(
                        'Record Payment',
                        style: AppTextStyles.button,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: context.appAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () => _showLinkTransactionSheet(debt),
                    icon: const Icon(Icons.link_rounded),
                    color: context.appAccent,
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    tooltip: 'Link existing transaction',
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: AppColors.positive.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _markAsPaid,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    color: AppColors.positive,
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    tooltip: 'Mark as Paid',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String? _dueRelativeLabel(Debt debt) {
    if (debt.status == DebtStatus.paid) return null;
    final days = debt.getDaysUntilDue();
    if (days == null) return null;
    if (days < 0) {
      final n = -days;
      return '$n ${n == 1 ? 'day' : 'days'} overdue';
    } else if (days == 0) {
      return 'due today';
    } else if (days == 1) {
      return 'due tomorrow';
    } else if (days <= 7) {
      return 'due in $days days';
    }
    return null;
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
