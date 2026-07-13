import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/settings_provider.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';
import '../utilities/functions.dart';

/// Opens the account-to-account transfer screen.
Future<void> showTransferSheet(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => const _TransferPage(),
      transitionsBuilder: (context, animation, secondary, child) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
    ),
  );
}

class _TransferPage extends StatefulWidget {
  const _TransferPage();

  @override
  State<_TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<_TransferPage> {
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocus = FocusNode();
  int? _fromId;
  int? _toId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final accounts =
        Provider.of<AccountProvider>(context, listen: false).accounts;
    if (accounts.isNotEmpty) _fromId = accounts.first.id;
    if (accounts.length > 1) _toId = accounts[1].id;
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountFocus.unfocus();
    _amountFocus.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  bool get _isValid =>
      _fromId != null &&
      _toId != null &&
      _fromId != _toId &&
      _amount > 0;

  Future<void> _submit() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);
    final txProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final accProvider =
        Provider.of<AccountProvider>(context, listen: false);
    try {
      await txProvider.addTransfer(
        fromAccountId: _fromId!,
        toAccountId: _toId!,
        amount: _amount,
        date: _date,
      );
      await accProvider.loadAccounts(); // refresh balances
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer recorded'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transfer failed: $e'),
          backgroundColor: AppColors.negative,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _swap() {
    setState(() {
      final t = _fromId;
      _fromId = _toId;
      _toId = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AccountProvider>().accounts;
    final currency = context.watch<SettingsProvider>().currencySymbol;

    if (accounts.length < 2) {
      return Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(title: const Text('Transfer')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'You need at least two accounts to make a transfer.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge
                  .copyWith(color: context.textSecondary),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.appBackground,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Transfer'),
        actions: [
          TextButton(
            onPressed: _isValid && !_saving ? _submit : null,
            child: Text(
              'Save',
              style: AppTextStyles.button.copyWith(
                color: _isValid ? context.appAccent : context.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currency,
                    style: AppTextStyles.h2.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      focusNode: _amountFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      onChanged: (_) => setState(() {}),
                      style: AppTextStyles.h1.copyWith(fontSize: 40),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: AppTextStyles.h1.copyWith(
                          fontSize: 40,
                          color: context.textSecondary.withValues(alpha: 0.4),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _accountSelector(
                context,
                label: 'FROM',
                accounts: accounts,
                selectedId: _fromId,
                currency: currency,
                onChanged: (v) => setState(() => _fromId = v),
              ),
              // Swap
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: GestureDetector(
                    onTap: _swap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.appAccent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.swap_vert_rounded,
                          color: context.appAccent),
                    ),
                  ),
                ),
              ),
              _accountSelector(
                context,
                label: 'TO',
                accounts: accounts,
                selectedId: _toId,
                currency: currency,
                onChanged: (v) => setState(() => _toId = v),
              ),

              if (_fromId != null && _fromId == _toId) ...[
                const SizedBox(height: 12),
                Text(
                  'Pick two different accounts.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.negative),
                ),
              ],

              const SizedBox(height: 24),
              // Date
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: context.appSurfaceLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 18, color: context.appAccent),
                      const SizedBox(width: 12),
                      Text(
                        UtilityFunction.formatDate(_date),
                        style: AppTextStyles.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountSelector(
    BuildContext context, {
    required String label,
    required List<Account> accounts,
    required int? selectedId,
    required String currency,
    required ValueChanged<int?> onChanged,
  }) {
    final selected = accounts.firstWhere(
      (a) => a.id == selectedId,
      orElse: () => accounts.first,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.appSurfaceLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: selectedId,
                dropdownColor: context.appSurface,
                borderRadius: BorderRadius.circular(14),
                items: accounts
                    .map(
                      (a) => DropdownMenuItem<int>(
                        value: a.id,
                        child: Text(
                          a.name,
                          style: AppTextStyles.bodyLarge
                              .copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
          Text(
            UtilityFunction.formatMoney(selected.currentBalance,
                symbol: currency),
            style: AppTextStyles.bodySmall.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }
}
