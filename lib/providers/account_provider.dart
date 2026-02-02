import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../db/account_db_helper.dart';

class AccountProvider extends ChangeNotifier {
  List<Account> _accounts = [];
  Account? _selectedAccount;
  bool _isLoaded = false;

  List<Account> get accounts => _accounts;
  Account? get selectedAccount => _selectedAccount;
  Account? get defaultAccount => _accounts.firstWhere((acc) => acc.isDefault,
      orElse: () => _accounts.first);
  bool get isLoaded => _isLoaded;

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
            final balance =
                await _dbHelper.calculateAccountBalance(account.id!);
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

      final result = await _dbHelper.deleteAccount(id);
      if (result > 0) {
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

  // Recalculate balance for a specific account
  Future<void> recalculateAccountBalance(int accountId) async {
    try {
      final balance = await _dbHelper.calculateAccountBalance(accountId);
      final account = _accounts.firstWhere((acc) => acc.id == accountId);
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
            initialBalance: account.initialBalance,
            currentBalance: account.currentBalance,
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
        initialBalance: targetAccount.initialBalance,
        currentBalance: targetAccount.currentBalance,
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
