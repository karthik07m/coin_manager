import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../utilities/functions.dart';
import '../models/activity_log.dart';
import '../services/activity_logger.dart';
import '../services/exchange_rate_service.dart';
import '../db/account_db_helper.dart';

/// One point on the net-worth-over-time trend.
class NetWorthPoint {
  final DateTime month; // first day of the month this point represents
  final double netWorth;
  final double assets;
  final double liabilities;
  const NetWorthPoint({
    required this.month,
    required this.netWorth,
    required this.assets,
    required this.liabilities,
  });
}

class AccountProvider extends ChangeNotifier {
  List<Account> _accounts = [];
  Account? _selectedAccount;
  bool _isLoaded = false;

  List<Account> get accounts => _accounts;
  Account? get selectedAccount => _selectedAccount;
  Account? get defaultAccount {
    if (_accounts.isEmpty) return null;
    return _accounts.firstWhere(
      (acc) => acc.isDefault,
      orElse: () => _accounts.first,
    );
  }

  bool get isLoaded => _isLoaded;

  // ---- Multi-currency: base currency + live rates -------------------------
  final ExchangeRateService _rateService = ExchangeRateService();
  String _baseCurrency = '';
  Map<String, double> _rates = {};

  String get baseCurrency => _baseCurrency;
  bool get hasMixedCurrencies =>
      _accounts.any((a) => a.currency.isNotEmpty && a.currency != _baseCurrency);

  /// Fired after FX rates finish loading, so dependent aggregations (e.g.
  /// transaction totals) can recompute. Wired to TransactionProvider in main.
  VoidCallback? onRatesChanged;

  /// Load live FX rates for [base] so mixed-currency balances can be summed.
  /// Safe to call repeatedly; only refetches when needed.
  Future<void> loadRates(String base) async {
    if (base.isEmpty) return;
    _baseCurrency = base;
    final rates = await _rateService.getRates(base);
    if (rates.isNotEmpty) {
      _rates = rates;
      notifyListeners();
      onRatesChanged?.call();
    }
  }

  /// Convert an amount held in [currency] into the base currency.
  double _toBase(double amount, String currency) =>
      ExchangeRateService.toBase(amount, currency, _baseCurrency, _rates);

  /// The account's current balance expressed in the base currency.
  double balanceInBase(Account a) => _toBase(a.currentBalance, a.currency);

  /// The currency an account holds. Accounts created before per-account
  /// currencies existed have an empty value and are treated as base currency,
  /// so two such accounts still compare equal.
  String currencyOfAccount(int accountId) {
    final acc = getAccountById(accountId);
    final code = acc?.currency ?? '';
    return code.isEmpty ? _baseCurrency : code;
  }

  /// Convert an [amount] belonging to account [accountId] into the base
  /// currency. Returns [amount] unchanged for base-currency accounts, unknown
  /// accounts, or when rates aren't loaded — so single-currency stays exact.
  double toBaseForAccount(int accountId, double amount) {
    final acc = getAccountById(accountId);
    if (acc == null) return amount;
    return _toBase(amount, acc.currency);
  }

  /// Assets = everything you own, converted to the base currency.
  double get totalAssets => _accounts
      .where((a) => !a.isLiability)
      .fold(0.0, (sum, a) => sum + _toBase(a.currentBalance, a.currency));

  /// Liabilities = what you owe (credit card balances), in the base currency.
  double get totalLiabilities => _accounts
      .where((a) => a.isLiability)
      .fold(0.0, (sum, a) => sum + _toBase(a.currentBalance, a.currency));

  /// Net worth = assets - liabilities, like real finance apps.
  double get netWorth => totalAssets - totalLiabilities;

  /// Credit cards that have a limit set (needed for usage/utilization math).
  List<Account> get _creditCardsWithLimit => _accounts
      .where((a) =>
          a.isLiability && a.creditLimit != null && a.creditLimit! > 0)
      .toList();

  bool get hasCreditCardsWithLimit => _creditCardsWithLimit.isNotEmpty;

  /// Combined credit limit across all credit cards, in the base currency.
  double get totalCreditLimit => _creditCardsWithLimit.fold(
      0.0, (sum, a) => sum + _toBase(a.creditLimit!, a.currency));

  /// Combined amount currently owed (used) across all cards, in base currency.
  double get totalCreditUsed => _creditCardsWithLimit.fold(
      0.0, (sum, a) => sum + _toBase(a.currentBalance, a.currency));

  /// Combined remaining credit across all credit cards.
  double get totalCreditAvailable => totalCreditLimit - totalCreditUsed;

  final AccountDBHelper _dbHelper = AccountDBHelper();

  // Load all accounts from database
  Future<void> loadAccounts() async {
    try {
      _accounts = await _dbHelper.getAllAccounts();
      if (_selectedAccount == null && _accounts.isNotEmpty) {
        _selectedAccount = _accounts.firstWhere(
          (acc) => acc.isDefault,
          orElse: () => _accounts.first,
        );
      }
      // Calculate current balances from transactions BEFORE notifying
      // listeners. Account.fromMap sets currentBalance = initialBalance,
      // which can be a back-calculated negative value after balance edits.
      // Notifying before recalculation caused the UI to briefly flash the
      // wrong (initialBalance) value — e.g. a negative number that would
      // then correct itself once the real balance was computed.
      await _calculateAllBalances();
      _isLoaded = true;
      notifyListeners();
      // An account's currency may have changed — refresh transaction totals
      // so multi-currency reporting stays in sync.
      onRatesChanged?.call();
    } catch (e) {
      debugPrint('Error loading accounts: $e');
      _isLoaded = true; // Ensure loaded even on error
      notifyListeners();
    }
  }

  // Calculate current balance for all accounts from transactions
  Future<void> _calculateAllBalances() async {
    try {
      for (var account in _accounts) {
        if (account.id != null) {
          try {
            final balance = await _dbHelper.calculateAccountBalance(
                account.id!,
                isLiability: account.isLiability);
            account.updateCurrentBalance(balance);
          } catch (e) {
            debugPrint(
                'Error calculating balance for account ${account.id}: $e');
            // Keep initial balance as current balance on error
            account.updateCurrentBalance(account.initialBalance);
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _calculateAllBalances: $e');
    }
  }

  // Select an account
  void selectAccount(Account account) {
    _selectedAccount = account;
    notifyListeners();
  }

  // Add a new account
  Future<bool> addAccount(Account account) async {
    try {
      final id = await _dbHelper.insertAccount(account);
      if (id > 0) {
        ActivityLogger().created(ActivityEntity.account, account.name,
            amount: account.initialBalance == 0 ? null : account.initialBalance);
        await loadAccounts(); // Reload to get the new account with ID
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error adding account: $e');
      return false;
    }
  }

  // Update an account
  /// [previousBalance] is only for the history entry: the caller mutates the
  /// account in place, so the old figure is gone by the time we get here.
  Future<bool> updateAccount(Account account, {double? previousBalance}) async {
    try {
      final result = await _dbHelper.updateAccount(account);
      if (result > 0) {
        final newBalance = account.currentBalance;
        final changed = previousBalance != null &&
            (previousBalance - newBalance).abs() > 0.005;
        ActivityLogger().updated(
          ActivityEntity.account,
          changed
              ? '${account.name}: ${UtilityFunction.formatMoney(previousBalance, showDecimals: true)} → ${UtilityFunction.formatMoney(newBalance, showDecimals: true)}'
              : account.name,
          amount: changed ? newBalance : null,
        );
        await loadAccounts(); // Reload to reflect changes
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating account: $e');
      return false;
    }
  }

  // Delete an account
  /// How many transactions would be affected by deleting this account —
  /// including transfers that merely *land* here, which would otherwise be
  /// left pointing at an account that no longer exists.
  Future<int> transactionCountFor(int id) =>
      _dbHelper.countTransactionsForAccount(id);

  /// Deletes an account. When it still has transactions the caller must say
  /// what happens to them: pass [reassignToAccountId] to move them to another
  /// account, or leave it null to delete them alongside the account.
  Future<bool> deleteAccount(int id, {int? reassignToAccountId}) async {
    try {
      final deletedName = getAccountById(id)?.name ?? 'Account';
      final result =
          await _dbHelper.deleteAccount(id, reassignToAccountId: reassignToAccountId);
      if (result > 0) {
        ActivityLogger().deleted(ActivityEntity.account, deletedName);
        await loadAccounts(); // Reload after deletion
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting account: $e');
      return false;
    }
  }

  // Get account by ID
  Account? getAccountById(int id) {
    try {
      return _accounts.firstWhere((account) => account.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Net worth at the end of each of the last [months] months (oldest first),
  /// reconstructed from transaction history. The final point matches the live
  /// net worth exactly (it counts all transactions, like the header does).
  Future<List<NetWorthPoint>> netWorthTrend({int months = 6}) async {
    final now = DateTime.now();
    final points = <NetWorthPoint>[];
    for (int i = months - 1; i >= 0; i--) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final isCurrent = i == 0;
      // For past months use the end-of-month cutoff; for the current month
      // count everything so the last point equals the displayed net worth.
      final cutoff = isCurrent
          ? DateTime(9999)
          : DateTime(monthStart.year, monthStart.month + 1, 1);
      double assets = 0.0;
      double liabilities = 0.0;
      for (final account in _accounts) {
        if (account.id == null) continue;
        final bal = await _dbHelper.calculateAccountBalanceAsOf(
          account.id!,
          cutoff,
          isLiability: account.isLiability,
        );
        // Convert to base currency (uses current rates as an approximation
        // for historical points — we don't store historical FX).
        final inBase = _toBase(bal, account.currency);
        if (account.isLiability) {
          liabilities += inBase;
        } else {
          assets += inBase;
        }
      }
      points.add(NetWorthPoint(
        month: monthStart,
        netWorth: assets - liabilities,
        assets: assets,
        liabilities: liabilities,
      ));
    }
    return points;
  }

  /// Recompute every account's current balance from the latest transactions
  /// WITHOUT re-reading the account rows. Call this after a transaction is
  /// added, edited, deleted, or transferred so balances/net worth/available
  /// credit stay live. No-op until accounts have been loaded at least once.
  Future<void> refreshBalances() async {
    if (!_isLoaded) return;
    // Force a full reload of accounts to ensure UI rebuilds with fresh object references
    await loadAccounts();
  }

  // Recalculate balance for a specific account
  Future<void> recalculateAccountBalance(int accountId) async {
    try {
      final account = _accounts.firstWhere((acc) => acc.id == accountId);
      final balance = await _dbHelper.calculateAccountBalance(accountId,
          isLiability: account.isLiability);
      account.updateCurrentBalance(balance);
      notifyListeners();
    } catch (e) {
      debugPrint('Error recalculating account balance: $e');
    }
  }

  // Set an account as default
  Future<bool> setDefaultAccount(int accountId) async {
    try {
      // First, unset all accounts as default
      for (final account in _accounts) {
        if (account.isDefault) {
          final updatedAccount = Account(
            id: account.id,
            name: account.name,
            icon: account.icon,
            color: account.color,
            type: account.type,
            initialBalance: account.initialBalance,
            currentBalance: account.currentBalance,
            creditLimit: account.creditLimit,
            currency: account.currency,
            isDefault: false,
            createdOn: account.createdOn,
            modifiedOn: DateTime.now(),
          );
          await _dbHelper.updateAccount(updatedAccount);
        }
      }

      // Set the selected account as default
      final targetAccount = _accounts.firstWhere((acc) => acc.id == accountId);
      final updatedAccount = Account(
        id: targetAccount.id,
        name: targetAccount.name,
        icon: targetAccount.icon,
        color: targetAccount.color,
        type: targetAccount.type,
        initialBalance: targetAccount.initialBalance,
        currentBalance: targetAccount.currentBalance,
        creditLimit: targetAccount.creditLimit,
        currency: targetAccount.currency,
        isDefault: true,
        createdOn: targetAccount.createdOn,
        modifiedOn: DateTime.now(),
      );

      final result = await _dbHelper.updateAccount(updatedAccount);
      if (result > 0) {
        await loadAccounts(); // Reload to reflect changes
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error setting default account: $e');
      return false;
    }
  }

  // Calculate total balance across all accounts
  double get totalBalance {
    return _accounts.fold(0.0, (sum, account) => sum + account.currentBalance);
  }
}
