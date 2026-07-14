import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/activity_log.dart';
import '../services/activity_logger.dart';
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

  /// Assets = everything you own (checking, savings, cash, investments...).
  double get totalAssets => _accounts
      .where((a) => !a.isLiability)
      .fold(0.0, (sum, a) => sum + a.currentBalance);

  /// Liabilities = what you owe (credit card balances).
  double get totalLiabilities => _accounts
      .where((a) => a.isLiability)
      .fold(0.0, (sum, a) => sum + a.currentBalance);

  /// Net worth = assets - liabilities, like real finance apps.
  double get netWorth => totalAssets - totalLiabilities;

  /// Credit cards that have a limit set (needed for usage/utilization math).
  List<Account> get _creditCardsWithLimit => _accounts
      .where((a) =>
          a.isLiability && a.creditLimit != null && a.creditLimit! > 0)
      .toList();

  bool get hasCreditCardsWithLimit => _creditCardsWithLimit.isNotEmpty;

  /// Combined credit limit across all credit cards.
  double get totalCreditLimit =>
      _creditCardsWithLimit.fold(0.0, (sum, a) => sum + a.creditLimit!);

  /// Combined amount currently owed (used) across all credit cards.
  double get totalCreditUsed =>
      _creditCardsWithLimit.fold(0.0, (sum, a) => sum + a.currentBalance);

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
      _isLoaded = true; // Set loaded first
      notifyListeners();

      // Calculate current balances from transactions (async, non-blocking)
      await _calculateAllBalances();
      notifyListeners(); // Update UI after balance calculation
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
  Future<bool> updateAccount(Account account) async {
    try {
      final result = await _dbHelper.updateAccount(account);
      if (result > 0) {
        ActivityLogger().updated(ActivityEntity.account, account.name);
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
  Future<bool> deleteAccount(int id) async {
    try {
      // Check if account has transactions
      final hasTransactions = await _dbHelper.hasTransactions(id);
      if (hasTransactions) {
        debugPrint('Cannot delete account with transactions');
        return false;
      }

      final deletedName = getAccountById(id)?.name ?? 'Account';
      final result = await _dbHelper.deleteAccount(id);
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
        if (account.isLiability) {
          liabilities += bal;
        } else {
          assets += bal;
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
    await _calculateAllBalances();
    notifyListeners();
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
