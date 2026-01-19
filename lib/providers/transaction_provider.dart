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
  List<CategoryAmount> categories = [];

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

    _transactions.clear();
    _transactions.addAll(transactionsFromDB);

    _updateTotalsForMonth(
        startDate ?? DateTime.now(), endDate ?? DateTime.now());
    _calculateCategoryAmounts();
    isTransactionsLoaded = true; // Set to true after loading
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
    _calculateCategoryAmounts(); // Update pie chart categories
    notifyListeners();
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
      _calculateCategoryAmounts(); // Update pie chart categories
      notifyListeners();
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
    _calculateCategoryAmounts(); // Update pie chart categories
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

  void _calculateCategoryAmounts() async {
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
          name: categoryDetails['name'], // category name
          icon: categoryDetails['icon'], // category icon
          amount: amount,
        ));
      }
    }

    // Update the categories list
    categories = categoryList;
    notifyListeners();
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

    for (var originalTransaction in recurringTransactions) {
      // Determine the target date for this month
      // We process only if the original transaction is from a PREVIOUS month
      if (originalTransaction.date.year < now.year ||
          (originalTransaction.date.year == now.year &&
              originalTransaction.date.month < now.month)) {
        // Calculate the target day for current month
        // Handle edge cases like Feb 30th -> Feb 28th/29th
        int targetDay = originalTransaction.date.day;
        int lastDayOfCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
        int actualDay = targetDay > lastDayOfCurrentMonth
            ? lastDayOfCurrentMonth
            : targetDay;

        DateTime targetDate = DateTime(now.year, now.month, actualDay);

        // Check if this recurrence has already been processed for this month
        // We assume uniqueness by title, category, amount, and the fact that it's in the current month
        // Is there a better way? Ideally, we'd link them via a parent_id, but for now this heuristic works
        // provided the user doesn't create identical transactions manually.
        bool existsForThisMonth = _transactions.any((t) {
          return t.title == originalTransaction.title &&
              t.categoryId == originalTransaction.categoryId &&
              t.amount == originalTransaction.amount &&
              t.date.year == now.year &&
              t.date.month == now.month &&
              t.isRecurring;
        });

        // Also check DB if _transactions list is not fully loaded or filtered
        if (!existsForThisMonth) {
          // Double check against DB for current month to be safe
          final transactionsThisMonth = await _dbHelper.getTransactionsByType(
            startDate: DateTime(now.year, now.month, 1),
            endDate: DateTime(now.year, now.month + 1, 0),
          );
          existsForThisMonth = transactionsThisMonth.any((t) =>
              t.title == originalTransaction.title &&
              t.categoryId == originalTransaction.categoryId &&
              t.amount == originalTransaction.amount &&
              t.isRecurring);
        }

        if (!existsForThisMonth) {
          // Clone and Create
          Transaction newTransaction = Transaction.createNew(
            id: DateTime.now().millisecondsSinceEpoch.toString() +
                originalTransaction.id.substring(0, 5), // Ensure unique ID
            title: originalTransaction.title,
            amount: originalTransaction.amount,
            categoryId: originalTransaction.categoryId,
            date: targetDate,
            isExpense: originalTransaction.isExpense,
            isRecurring:
                true, // The new one is also recurring so it propagates?
            // actually, if we mark it recurring, it might trigger again next month from THIS one.
            // But our check ensures we only check existing recurring ones.
            // If we mark the new one as recurring, next month we might find TWO recurring ones (original + this one)
            // and spawn duplicates.
            // DECISION: The generated transaction should PROBABLY NOT be marked 'isRecurring' itself to avoid
            // checking it as a *source* of recurrence, UNLESS we want to 'move' the recurrence.
            // BUT, the user wants it to recur "every month".
            // If the user *edits* the new one, they might expect it to update future ones.
            // FOR SIMPLICITY: The 'original' transaction is the definition. The generated ones are instances.
            // So generated instances should have isRecurring = true so the UI shows it's a recurring item,
            // BUT we must filter our 'source' check to exclude transactions generated FOR the current month.
            // Refined Logic (Line 158): check if source is from previous month.
            // Since `originalTransaction.date` < `now`, the NEW transaction (which has date `now`) won't match the condition
            // to generate a child next time we run this loop for *this* month.
            // Next month, `newTransaction` will be 'old', and it might trigger a generation.
            // This causes checking N past transactions.
            // To prevent exponential growth or duplicates from multiple parents:
            // Ideally we need a `parentTransactionId`.
            // Without schema change: relying on exact match deduplication.
          );

          await addTransaction(newTransaction);
        }
      }
    }
  }
}
