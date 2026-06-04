import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/account.dart';
import 'transaction_db_helper.dart';

class AccountDBHelper {
  static final AccountDBHelper _instance = AccountDBHelper._internal();
  factory AccountDBHelper() => _instance;

  AccountDBHelper._internal();

  final String tableName = 'accounts';
  final String columnId = 'id';
  final String columnName = 'name';
  final String columnIcon = 'icon';
  final String columnColor = 'color';
  String columnBalance =
      'balance'; // Will be updated to 'initial_balance' after migration
  final String columnIsDefault = 'is_default';
  final String columnCreatedOn = 'created_on';
  final String columnModifiedOn = 'modified_on';

  // Get database from TransactionDBHelper to ensure it's the same instance
  Future<Database> get database async {
    return await TransactionDBHelper().database;
  }

  // Check which balance column exists and update columnBalance accordingly
  Future<void> _detectBalanceColumn() async {
    try {
      final db = await database;
      final columns = await db.rawQuery('PRAGMA table_info(accounts)');
      final hasInitialBalance =
          columns.any((col) => col['name'] == 'initial_balance');

      if (hasInitialBalance) {
        columnBalance = 'initial_balance';
      } else {
        columnBalance = 'balance'; // Use old column name
      }
    } catch (e) {
      debugPrint('Error detecting balance column: $e');
      columnBalance = 'balance'; // Default to old column
    }
  }

  // Create default accounts - called during database migration
  static Future<void> createDefaultAccounts(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Check which column to use
    final columns = await db.rawQuery('PRAGMA table_info(accounts)');
    final hasInitialBalance =
        columns.any((col) => col['name'] == 'initial_balance');
    final balanceColumnName = hasInitialBalance ? 'initial_balance' : 'balance';

    final defaultAccounts = [
      {
        'name': 'Cash',
        'icon': 'wallet',
        'color': '#4CAF50',
        balanceColumnName: 0.0,
        'is_default': 1,
        'created_on': now,
        'modified_on': now,
      },
      {
        'name': 'Bank Account',
        'icon': 'account_balance',
        'color': '#2196F3',
        balanceColumnName: 0.0,
        'is_default': 0,
        'created_on': now,
        'modified_on': now,
      },
      {
        'name': 'Credit Card',
        'icon': 'credit_card',
        'color': '#FF9800',
        balanceColumnName: 0.0,
        'is_default': 0,
        'created_on': now,
        'modified_on': now,
      },
      {
        'name': 'Debit Card',
        'icon': 'payment',
        'color': '#9C27B0',
        balanceColumnName: 0.0,
        'is_default': 0,
        'created_on': now,
        'modified_on': now,
      },
    ];

    for (var account in defaultAccounts) {
      await db.insert('accounts', account);
    }
  }

  // Insert an account
  Future<int> insertAccount(Account account) async {
    await _detectBalanceColumn(); // Ensure we have the right column name
    final db = await database;
    return await db.insert(tableName, account.toMap());
  }

  // Update an account
  Future<int> updateAccount(Account account) async {
    await _detectBalanceColumn();
    final db = await database;
    return await db.update(
      tableName,
      account.toMap(),
      where: '$columnId = ?',
      whereArgs: [account.id],
    );
  }

  // Delete an account
  Future<int> deleteAccount(int id) async {
    final db = await database;
    return await db.delete(
      tableName,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Get all accounts
  Future<List<Account>> getAllAccounts() async {
    await _detectBalanceColumn(); // Detect column before querying
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      orderBy: '$columnIsDefault DESC, $columnId ASC',
    );

    return List.generate(maps.length, (i) => Account.fromMap(maps[i]));
  }

  // Get account by ID
  Future<Account?> getAccountById(int id) async {
    await _detectBalanceColumn();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: '$columnId = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) {
      return null;
    }

    return Account.fromMap(maps.first);
  }

  // Get default account
  Future<Account?> getDefaultAccount() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: '$columnIsDefault = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Account.fromMap(maps.first);
  }

  // Calculate current balance  for an account from initial balance + transactions
  Future<double> calculateAccountBalance(int accountId) async {
    try {
      final db = await database;

      // Get initial balance
      final accountMaps = await db.query(
        tableName,
        columns: [columnBalance],
        where: '$columnId = ?',
        whereArgs: [accountId],
      );

      if (accountMaps.isEmpty) return 0.0;

      // Handle both int and double from SQLite
      final balanceValue = accountMaps.first[columnBalance];
      final initialBalance = balanceValue is int
          ? balanceValue.toDouble()
          : (balanceValue as double? ?? 0.0);

      // Calculate transaction impact
      final transactionResult = await db.rawQuery(
        '''
      SELECT 
        SUM(CASE WHEN is_expense = 0 THEN amount ELSE 0 END) as income,
        SUM(CASE WHEN is_expense = 1 THEN amount ELSE 0 END) as expense
      FROM transactions
      WHERE account_id = ?
      ''',
        [accountId],
      );

      if (transactionResult.isEmpty) return initialBalance;

      // Handle both int and double from SQLite SUM operations
      final incomeValue = transactionResult.first['income'];
      final expenseValue = transactionResult.first['expense'];
      final income = incomeValue is int
          ? incomeValue.toDouble()
          : (incomeValue as double? ?? 0.0);
      final expense = expenseValue is int
          ? expenseValue.toDouble()
          : (expenseValue as double? ?? 0.0);

      return initialBalance + income - expense;
    } catch (e) {
      debugPrint('Error calculating account balance for $accountId: $e');
      return 0.0; // Return 0 on error rather than crashing
    }
  }

  // Update account balance (now updates initial_balance)
  Future<int> updateAccountBalance(int id, double newBalance) async {
    final db = await database;
    return await db.update(
      tableName,
      {
        columnBalance: newBalance,
        columnModifiedOn: DateTime.now().toIso8601String(),
      },
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Check if account has transactions
  Future<bool> hasTransactions(int accountId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE account_id = ?',
      [accountId],
    );
    return (result.first['count'] as int) > 0;
  }
}
