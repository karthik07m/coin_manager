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
}
