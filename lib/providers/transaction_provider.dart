import 'package:flutter/material.dart';
import '../db/category_db_helper.dart';
import '../models/category_amount.dart';
import '../models/transaction.dart';
import '../db/transaction_db_helper.dart';

class TransactionProvider extends ChangeNotifier {
  final List<Transaction> _transactions = [];
  bool isTransactionsLoaded = false; // Add this property
  double totalExpenses = 0.0;
  double totalIncome = 0.0;
  final TransactionDBHelper _dbHelper = TransactionDBHelper();

  List<Transaction> get transactions => _transactions;
  List<Transaction> _upcomingTransactions = [];
  List<Transaction> get upcomingTransactions => _upcomingTransactions;
  List<CategoryAmount> categories = [];

  // Previous month comparison
  double _previousMonthExpenses = 0.0;
  DateTime? _cachedPreviousMonth;

  double get previousMonthExpenses => _previousMonthExpenses;

  Future<void> loadTransactionsFromDB({
    bool? isExpense,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<Transaction> transactionsFromDB =
        await _dbHelper.getTransactionsByType(
      isExpense: isExpense,
      startDate: startDate,
      endDate: endDate,
    );

    // Filter out future transactions - only show transactions on or before today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final filteredTransactions = transactionsFromDB
        .where((transaction) => !transaction.date.isAfter(today))
        .toList();

    _transactions.clear();
    _transactions.addAll(filteredTransactions);

    _updateTotalsForMonth(
        startDate ?? DateTime.now(), endDate ?? DateTime.now());
    _calculateCategoryAmounts();
    isTransactionsLoaded = true; // Set to true after loading
    notifyListeners();
  }

  Future<void> loadUpcomingTransactions() async {
    _upcomingTransactions = await _dbHelper.getUpcomingRecurringTransactions();
    // Also load all transactions to ensure total is accurate
    _allUpcomingTransactions =
        await _dbHelper.getAllUpcomingRecurringTransactions();
    debugPrint(
        '📅 loadUpcomingTransactions: Loaded ${_upcomingTransactions.length} for widget, ${_allUpcomingTransactions.length} total');
    for (var tx in _upcomingTransactions) {
      debugPrint('  → ${tx.title} on ${tx.date}');
    }
    notifyListeners();
  }

  // For full-screen view - all upcoming transactions
  List<Transaction> _allUpcomingTransactions = [];
  List<Transaction> get allUpcomingTransactions => _allUpcomingTransactions;

  // Computed total from all upcoming transactions (for consistency)
  double get totalUpcomingAmount {
    return _allUpcomingTransactions.fold<double>(
      0.0,
      (sum, transaction) => sum + transaction.amount,
    );
  }

  Future<void> loadAllUpcomingTransactions() async {
    _allUpcomingTransactions =
        await _dbHelper.getAllUpcomingRecurringTransactions();
    debugPrint(
        '📅 loadAllUpcomingTransactions: Loaded ${_allUpcomingTransactions.length} transactions');
    notifyListeners();
  }

  Future<Transaction?> getTransactionById(String id) async {
    return await _dbHelper.getTransactionById(id);
  }

  Future<void> addTransaction(Transaction transaction) async {
    await _dbHelper.insertTransaction(transaction);
    _transactions.add(transaction);

    DateTime startDate =
        DateTime(transaction.date.year, transaction.date.month, 1);
    DateTime endDate =
        DateTime(transaction.date.year, transaction.date.month + 1, 0);

    _updateTotalsForMonth(startDate, endDate);
    await _calculateCategoryAmounts(); // Await to avoid double-notify race
    await loadUpcomingTransactions(); // Refresh upcoming payments
    notifyListeners(); // Single notify after ALL data is ready
  }

  Future<void> updateTransaction(Transaction transaction) async {
    int index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
      await _dbHelper.updateTransaction(transaction);

      DateTime startDate =
          DateTime(transaction.date.year, transaction.date.month, 1);
      DateTime endDate =
          DateTime(transaction.date.year, transaction.date.month + 1, 0);

      _updateTotalsForMonth(startDate, endDate);
      await _calculateCategoryAmounts(); // Await to avoid double-notify race
      await loadUpcomingTransactions(); // Refresh upcoming payments
      notifyListeners(); // Single notify after ALL data is ready
    }
  }

  Future<void> deleteTransaction(String id) async {
    final transaction = _transactions.firstWhere((t) => t.id == id);
    _transactions.removeWhere((t) => t.id == id);
    await _dbHelper.deleteTransaction(id);

    DateTime startDate =
        DateTime(transaction.date.year, transaction.date.month, 1);
    DateTime endDate =
        DateTime(transaction.date.year, transaction.date.month + 1, 0);

    _updateTotalsForMonth(startDate, endDate);
    await _calculateCategoryAmounts(); // Await to avoid double-notify race
    await loadUpcomingTransactions(); // Refresh upcoming payments
    notifyListeners(); // Single notify after ALL data is ready
  }

  /// Stop a recurring payment by disabling its recurring flag and deleting all future instances
  Future<void> stopRecurringPayment(Transaction transaction) async {
    // Set isRecurring to false
    transaction.isRecurring = false;
    transaction.modifiedOn = DateTime.now();

    // Update the transaction in database
    await _dbHelper.updateTransaction(transaction);

    // Delete all future recurring instances
    await _dbHelper.deleteFutureRecurringInstances(transaction);

    // Update local state
    int index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
    }

    // Refresh upcoming transactions
    await loadUpcomingTransactions();

    notifyListeners();
  }

  void _updateTotalsForMonth(DateTime startDate, DateTime endDate) {
    totalExpenses = _transactions
        .where((transaction) =>
            transaction.isExpense &&
            transaction.date
                .isAfter(startDate.subtract(const Duration(days: 1))) &&
            transaction.date.isBefore(endDate.add(const Duration(days: 1))))
        .fold(0.0, (sum, transaction) => sum + transaction.amount);

    totalIncome = _transactions
        .where((transaction) =>
            !transaction.isExpense &&
            transaction.date
                .isAfter(startDate.subtract(const Duration(days: 1))) &&
            transaction.date.isBefore(endDate.add(const Duration(days: 1))))
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  // Returns Future<void> so callers can await it and avoid race conditions
  // where notifyListeners() fires before category data is computed.
  // The internal notifyListeners() call has been removed — callers manage that.
  Future<void> _calculateCategoryAmounts() async {
    Map<int, double> categoryTotals = {};

    // Calculate the total amount per category
    for (var transaction in _transactions) {
      if (transaction.isExpense) {
        if (categoryTotals.containsKey(transaction.categoryId)) {
          categoryTotals[transaction.categoryId] =
              categoryTotals[transaction.categoryId]! + transaction.amount;
        } else {
          categoryTotals[transaction.categoryId] = transaction.amount;
        }
      }
    }

    // Fetch category details (name and icon) for each category ID
    List<CategoryAmount> categoryList = [];

    for (var entry in categoryTotals.entries) {
      int categoryId = entry.key;
      double amount = entry.value;

      // Fetch category details from DB
      final categoryDetails =
          await DBHelper().getCategoryDetailsById(categoryId);

      if (categoryDetails != null) {
        categoryList.add(CategoryAmount(
          id: categoryId,
          name: categoryDetails['name'],
          icon: categoryDetails['icon'],
          amount: amount,
        ));
      } else {
        // Handle unknown/deleted categories
        categoryList.add(CategoryAmount(
          id: categoryId,
          name: 'Unknown',
          icon: 'assets/categories/other.png',
          amount: amount,
        ));
      }
    }

    // Update the categories list — caller will notify.
    categories = categoryList;
  }

  List<Transaction> getTransactionsByCategory(int categoryId) {
    return _transactions
        .where((transaction) => transaction.categoryId == categoryId)
        .toList();
  }

  /// Get total spending for a specific category within a date range
  double getCategorySpending(
      int categoryId, DateTime startDate, DateTime endDate) {
    return _transactions
        .where((transaction) =>
            transaction.categoryId == categoryId &&
            transaction.isExpense &&
            transaction.date
                .isAfter(startDate.subtract(const Duration(days: 1))) &&
            transaction.date.isBefore(endDate.add(const Duration(days: 1))))
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  Future<void> checkAndGenerateRecurringTransactions() async {
    final recurringTransactions = await _dbHelper.getRecurringTransactions();
    final now = DateTime.now();

    debugPrint(
        '🔄 checkAndGenerateRecurringTransactions: Found ${recurringTransactions.length} recurring transactions');

    for (var originalTransaction in recurringTransactions) {
      final isCurrentMonth = originalTransaction.date.year == now.year &&
          originalTransaction.date.month == now.month;
      final isPreviousMonth = originalTransaction.date.year < now.year ||
          (originalTransaction.date.year == now.year &&
              originalTransaction.date.month < now.month);

      debugPrint(
          '  📋 Processing: ${originalTransaction.title}, Date: ${originalTransaction.date}, isCurrentMonth: $isCurrentMonth, isPreviousMonth: $isPreviousMonth');

      if (isPreviousMonth) {
        // For previous month transactions: generate current + next month
        await _generateRecurringInstance(
          originalTransaction,
          now.year,
          now.month,
        );

        final nextMonth = DateTime(now.year, now.month + 1, 1);
        await _generateRecurringInstance(
          originalTransaction,
          nextMonth.year,
          nextMonth.month,
        );
      } else if (isCurrentMonth) {
        // For current month transactions: only generate next month
        // (current month instance already exists as the original)
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        await _generateRecurringInstance(
          originalTransaction,
          nextMonth.year,
          nextMonth.month,
        );
      }
    }

    debugPrint('✅ checkAndGenerateRecurringTransactions: Completed');
  }

  /// Helper method to generate a recurring transaction instance for a specific month
  Future<void> _generateRecurringInstance(
    Transaction originalTransaction,
    int targetYear,
    int targetMonth,
  ) async {
    // Calculate the target day for the specified month
    // Handle edge cases like Feb 30th -> Feb 28th/29th
    int targetDay = originalTransaction.date.day;
    int lastDayOfMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    int actualDay = targetDay > lastDayOfMonth ? lastDayOfMonth : targetDay;

    DateTime targetDate = DateTime(targetYear, targetMonth, actualDay);

    // Check if this recurrence has already been processed for this month
    // Check against DB for the target month to avoid duplicates
    final transactionsThisMonth = await _dbHelper.getTransactionsByType(
      startDate: DateTime(targetYear, targetMonth, 1),
      endDate: DateTime(targetYear, targetMonth + 1, 0),
    );

    bool existsForThisMonth = transactionsThisMonth.any((t) =>
        t.title == originalTransaction.title &&
        t.categoryId == originalTransaction.categoryId &&
        t.amount == originalTransaction.amount &&
        t.isRecurring);

    if (!existsForThisMonth) {
      // Clone and Create
      Transaction newTransaction = Transaction.createNew(
        id: DateTime.now().millisecondsSinceEpoch.toString() +
            originalTransaction.id.substring(0, 5), // Ensure unique ID
        title: originalTransaction.title,
        amount: originalTransaction.amount,
        categoryId: originalTransaction.categoryId,
        accountId: originalTransaction.accountId,
        date: targetDate,
        isExpense: originalTransaction.isExpense,
        isRecurring: true,
      );

      await addTransaction(newTransaction);
    }
  }

  /// Fetch previous month's total expenses for comparison
  /// Uses caching to avoid redundant DB queries
  Future<void> loadPreviousMonthExpenses(DateTime currentMonth) async {
    final prevMonth = DateTime(
      currentMonth.month == 1 ? currentMonth.year - 1 : currentMonth.year,
      currentMonth.month == 1 ? 12 : currentMonth.month - 1,
      1,
    );

    // Check cache to avoid redundant queries
    if (_cachedPreviousMonth != null &&
        _cachedPreviousMonth!.year == prevMonth.year &&
        _cachedPreviousMonth!.month == prevMonth.month) {
      return; // Already cached
    }

    final startDate = DateTime(prevMonth.year, prevMonth.month, 1);
    final endDate = DateTime(prevMonth.year, prevMonth.month + 1, 0);

    final transactions = await _dbHelper.getTransactionsByType(
      startDate: startDate,
      endDate: endDate,
    );

    _previousMonthExpenses = transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);

    _cachedPreviousMonth = prevMonth;
    notifyListeners();
  }

  /// Group transactions by day for calendar view
  Map<DateTime, List<Transaction>> getTransactionsByDay(DateTime month) {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);

    Map<DateTime, List<Transaction>> grouped = {};

    for (var transaction in _transactions) {
      if (transaction.date
              .isAfter(startDate.subtract(const Duration(days: 1))) &&
          transaction.date.isBefore(endDate.add(const Duration(days: 1)))) {
        final day = DateTime(
          transaction.date.year,
          transaction.date.month,
          transaction.date.day,
        );

        if (!grouped.containsKey(day)) {
          grouped[day] = [];
        }
        grouped[day]!.add(transaction);
      }
    }

    return grouped;
  }

  /// Get total expenses for a specific day
  double getDayExpenses(DateTime day) {
    return _transactions
        .where((t) =>
            t.isExpense &&
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Get total income for a specific day
  double getDayIncome(DateTime day) {
    return _transactions
        .where((t) =>
            !t.isExpense &&
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Get transactions for a specific day
  List<Transaction> getTransactionsForDay(DateTime day) {
    return _transactions
        .where((t) =>
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day)
        .toList();
  }
}
