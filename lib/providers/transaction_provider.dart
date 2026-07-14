import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../db/category_db_helper.dart';
import '../db/receipt_db_helper.dart';
import '../services/bill_reminder_scheduler.dart';
import '../utilities/id_generator.dart';
import '../models/category_amount.dart';
import '../models/transaction.dart';
import '../models/activity_log.dart';
import '../services/activity_logger.dart';
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

  /// Hook fired after any mutation that changes account balances (add / edit /
  /// delete / transfer). Wired to AccountProvider.refreshBalances() in main so
  /// account balances, net worth, and available credit stay live without the
  /// user needing to reopen the accounts screen.
  Future<void> Function()? onBalancesAffected;

  Future<void> _notifyBalancesAffected() async {
    final cb = onBalancesAffected;
    if (cb != null) await cb();
  }

  /// Resolves a transaction's amount into the base currency (wired to
  /// AccountProvider in main). Null / base-currency accounts return the raw
  /// amount, so single-currency reporting is unchanged.
  double Function(int accountId, double amount)? baseAmountResolver;

  /// A transaction's amount expressed in the user's base currency.
  double baseAmount(Transaction t) => baseAmountResolver == null
      ? t.amount
      : baseAmountResolver!(t.accountId, t.amount);

  DateTime? _lastTotalsStart;
  DateTime? _lastTotalsEnd;

  /// Recompute totals/category amounts for the last-used range and notify.
  /// Called when FX rates load so converted figures refresh.
  Future<void> reapplyRates() async {
    if (_lastTotalsStart != null && _lastTotalsEnd != null) {
      _updateTotalsForMonth(_lastTotalsStart!, _lastTotalsEnd!);
    }
    await _calculateCategoryAmounts();
    notifyListeners();
  }

  // Previous month comparison
  double _previousMonthExpenses = 0.0;
  DateTime? _cachedPreviousMonth;

  double get previousMonthExpenses => _previousMonthExpenses;

  Future<void> loadTransactionsFromDB({
    bool? isExpense,
    DateTime? startDate,
    DateTime? endDate,
    // Totals can be scoped narrower than the loaded range, so a screen can
    // prefetch adjacent months without skewing month totals for consumers.
    DateTime? totalsStartDate,
    DateTime? totalsEndDate,
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
        totalsStartDate ?? startDate ?? DateTime.now(),
        totalsEndDate ?? endDate ?? DateTime.now());
    _calculateCategoryAmounts();
    isTransactionsLoaded = true; // Set to true after loading
    notifyListeners();
  }

  Future<void> loadUpcomingTransactions({bool notify = true}) async {
    _upcomingTransactions = await _dbHelper.getUpcomingRecurringTransactions();
    // Also load all transactions to ensure total is accurate
    _allUpcomingTransactions =
        await _dbHelper.getAllUpcomingRecurringTransactions();
    if (notify) {
      notifyListeners();
    }
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

  Future<void> loadAllUpcomingTransactions({bool notify = true}) async {
    _allUpcomingTransactions =
        await _dbHelper.getAllUpcomingRecurringTransactions();
    debugPrint(
        '📅 loadAllUpcomingTransactions: Loaded ${_allUpcomingTransactions.length} transactions');
    if (notify) {
      notifyListeners();
    }
  }

  Future<Transaction?> getTransactionById(String id) async {
    return await _dbHelper.getTransactionById(id);
  }

  /// Category most recently used for a transaction with this exact title,
  /// so the form can auto-suggest it for repeated titles (e.g. "Starbucks").
  Future<int?> getLastCategoryForTitle(String title, bool isExpense) async {
    return await _dbHelper.getLastCategoryIdForTitle(title, isExpense);
  }

  Future<void> addTransaction(Transaction transaction) async {
    if (transaction.isRecurring) {
      transaction.recurrenceId ??= transaction.id;
    }

    await _dbHelper.insertTransaction(transaction);
    _transactions.add(transaction);

    DateTime startDate =
        DateTime(transaction.date.year, transaction.date.month, 1);
    DateTime endDate =
        DateTime(transaction.date.year, transaction.date.month + 1, 0);

    _updateTotalsForMonth(startDate, endDate);
    await _calculateCategoryAmounts(); // Await to avoid double-notify race
    await loadUpcomingTransactions(notify: false); // Refresh upcoming payments
    notifyListeners(); // Single notify after ALL data is ready
    await _notifyBalancesAffected();
    ActivityLogger().created(ActivityEntity.transaction, transaction.title,
        amount: transaction.amount);
    // Only recurring bills feed the reminder scheduler; skip the churn on
    // ordinary one-off transactions.
    if (transaction.isRecurring) BillReminderScheduler().reschedule();
  }

  /// Records a money movement between two accounts as a single transfer row.
  Future<void> addTransfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    final transfer = Transaction.createTransfer(
      id: newId(),
      amount: amount,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      date: date,
      title: note,
    );
    await _dbHelper.insertTransaction(transfer);
    _transactions.add(transfer);

    final startDate = DateTime(date.year, date.month, 1);
    final endDate = DateTime(date.year, date.month + 1, 0);
    _updateTotalsForMonth(startDate, endDate);
    await _calculateCategoryAmounts();
    notifyListeners();
    await _notifyBalancesAffected();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final existingTransaction =
        await _dbHelper.getTransactionById(transaction.id);
    final shouldRefreshRecurringSeries = existingTransaction != null &&
        _shouldRefreshRecurringSeries(existingTransaction, transaction);

    if (transaction.isRecurring) {
      transaction.recurrenceId ??=
          existingTransaction?.recurrenceId ?? transaction.id;
    } else {
      transaction.recurrenceId = null;
    }

    if (shouldRefreshRecurringSeries) {
      await _dbHelper.deleteFutureRecurringInstances(
        existingTransaction,
        excludeId: transaction.id,
      );
    }

    await _dbHelper.updateTransaction(transaction);

    int index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
    }

    if (transaction.isRecurring && shouldRefreshRecurringSeries) {
      await checkAndGenerateRecurringTransactions();
    }

    DateTime startDate =
        DateTime(transaction.date.year, transaction.date.month, 1);
    DateTime endDate =
        DateTime(transaction.date.year, transaction.date.month + 1, 0);

    _updateTotalsForMonth(startDate, endDate);
    await _calculateCategoryAmounts(); // Await to avoid double-notify race
    await loadUpcomingTransactions(notify: false); // Refresh upcoming payments
    notifyListeners(); // Single notify after ALL data is ready
    await _notifyBalancesAffected();
    ActivityLogger().updated(ActivityEntity.transaction, transaction.title,
        amount: transaction.amount);
    if (transaction.isRecurring) BillReminderScheduler().reschedule();
  }

  bool _shouldRefreshRecurringSeries(
    Transaction existingTransaction,
    Transaction updatedTransaction,
  ) {
    if (!existingTransaction.isRecurring) {
      return false;
    }

    if (!updatedTransaction.isRecurring) {
      return true;
    }

    return existingTransaction.date.day != updatedTransaction.date.day ||
        existingTransaction.title != updatedTransaction.title ||
        existingTransaction.amount != updatedTransaction.amount ||
        existingTransaction.categoryId != updatedTransaction.categoryId ||
        existingTransaction.accountId != updatedTransaction.accountId ||
        existingTransaction.isExpense != updatedTransaction.isExpense;
  }

  /// Deletes a receipt's DB row and its image file. Failures are logged but
  /// never abort the caller — a missing file must not block a delete.
  Future<void> _deleteReceipt(String receiptId) async {
    try {
      final receiptDb = ReceiptDBHelper();
      final receipt = await receiptDb.getReceiptById(receiptId);
      if (receipt != null) {
        final file = File(receipt.imagePath);
        if (await file.exists()) {
          await file.delete();
        }
        await receiptDb.deleteReceipt(receiptId);
      }
    } catch (e) {
      debugPrint('Receipt cleanup failed for $receiptId: $e');
    }
  }

  Future<void> deleteTransaction(String id) async {
    final transactionIndex = _transactions.indexWhere((t) => t.id == id);
    final transaction = transactionIndex == -1
        ? await _dbHelper.getTransactionById(id)
        : _transactions[transactionIndex];

    if (transaction == null) return;

    if (transaction.isRecurring) {
      final nextMonth = DateTime(
        transaction.date.year,
        transaction.date.month + 1,
        1,
      );
      await _generateRecurringInstance(
        transaction,
        nextMonth.year,
        nextMonth.month,
      );
    }

    _transactions.removeWhere((t) => t.id == id);
    await _dbHelper.deleteTransaction(id);

    // Clean up the attached receipt (row + image file) so deleting a
    // transaction never leaves an orphaned receipt behind.
    if (transaction.receiptId != null) {
      await _deleteReceipt(transaction.receiptId!);
    }

    DateTime startDate =
        DateTime(transaction.date.year, transaction.date.month, 1);
    DateTime endDate =
        DateTime(transaction.date.year, transaction.date.month + 1, 0);

    _updateTotalsForMonth(startDate, endDate);
    await _calculateCategoryAmounts(); // Await to avoid double-notify race
    await loadUpcomingTransactions(notify: false); // Refresh upcoming payments
    notifyListeners(); // Single notify after ALL data is ready
    await _notifyBalancesAffected();
    ActivityLogger().deleted(
      transaction.isTransfer
          ? ActivityEntity.transfer
          : ActivityEntity.transaction,
      transaction.title,
      amount: transaction.amount,
    );
    if (transaction.isRecurring) BillReminderScheduler().reschedule();
  }

  /// Stop a recurring payment by disabling its recurring flag and deleting all future instances
  Future<void> stopRecurringPayment(Transaction transaction) async {
    final recurrenceId = transaction.recurrenceId ?? transaction.id;
    await _dbHelper.deactivateRecurringSeries(transaction);

    // Update local state
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _transactions.removeWhere((t) =>
        t.isRecurring &&
        (t.recurrenceId ?? t.id) == recurrenceId &&
        t.date.isAfter(today));
    for (final item in _transactions) {
      if (item.isRecurring && (item.recurrenceId ?? item.id) == recurrenceId) {
        item.isRecurring = false;
        item.recurrenceId = null;
        item.modifiedOn = DateTime.now();
      }
    }

    // Refresh upcoming transactions
    await loadUpcomingTransactions(notify: false);

    notifyListeners();
    BillReminderScheduler().reschedule();
  }

  void _updateTotalsForMonth(DateTime startDate, DateTime endDate) {
    _lastTotalsStart = startDate;
    _lastTotalsEnd = endDate;
    totalExpenses = _transactions
        .where((transaction) =>
            transaction.isExpense &&
            !transaction.isTransfer &&
            transaction.date
                .isAfter(startDate.subtract(const Duration(days: 1))) &&
            transaction.date.isBefore(endDate.add(const Duration(days: 1))))
        .fold(0.0, (sum, transaction) => sum + baseAmount(transaction));

    totalIncome = _transactions
        .where((transaction) =>
            !transaction.isExpense &&
            !transaction.isTransfer &&
            transaction.date
                .isAfter(startDate.subtract(const Duration(days: 1))) &&
            transaction.date.isBefore(endDate.add(const Duration(days: 1))))
        .fold(0.0, (sum, transaction) => sum + baseAmount(transaction));
  }

  // Returns Future<void> so callers can await it and avoid race conditions
  // where notifyListeners() fires before category data is computed.
  // The internal notifyListeners() call has been removed — callers manage that.
  Future<void> _calculateCategoryAmounts() async {
    Map<int, double> categoryTotals = {};

    // Calculate the total amount per category
    for (var transaction in _transactions) {
      if (transaction.isExpense && !transaction.isTransfer) {
        final amt = baseAmount(transaction);
        if (categoryTotals.containsKey(transaction.categoryId)) {
          categoryTotals[transaction.categoryId] =
              categoryTotals[transaction.categoryId]! + amt;
        } else {
          categoryTotals[transaction.categoryId] = amt;
        }
      }
    }

    // Fetch all category details in one query instead of one per category —
    // the per-id loop ran N sequential DB queries on every save/load.
    final allCategories = await DBHelper().getAllCategories();
    final detailsById = {
      for (final row in allCategories) row['id'] as int: row,
    };

    List<CategoryAmount> categoryList = [];

    for (var entry in categoryTotals.entries) {
      int categoryId = entry.key;
      double amount = entry.value;
      final categoryDetails = detailsById[categoryId];

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
            !transaction.isTransfer &&
            transaction.date
                .isAfter(startDate.subtract(const Duration(days: 1))) &&
            transaction.date.isBefore(endDate.add(const Duration(days: 1))))
        .fold(0.0, (sum, transaction) => sum + baseAmount(transaction));
  }

  Future<void> checkAndGenerateRecurringTransactions() async {
    final recurringTransactions = await _dbHelper.getRecurringTransactions();
    if (recurringTransactions.isEmpty) return;

    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    // Prefetch which series already have an instance in each target month,
    // so we don't re-query the whole month once per recurring series.
    final existingCurrentMonth =
        await _recurrenceIdsForMonth(now.year, now.month);
    final existingNextMonth =
        await _recurrenceIdsForMonth(nextMonth.year, nextMonth.month);

    debugPrint(
        '🔄 checkAndGenerateRecurringTransactions: Found ${recurringTransactions.length} recurring transactions');

    for (var originalTransaction in recurringTransactions) {
      final isCurrentMonth = originalTransaction.date.year == now.year &&
          originalTransaction.date.month == now.month;
      final isPreviousMonth = originalTransaction.date.year < now.year ||
          (originalTransaction.date.year == now.year &&
              originalTransaction.date.month < now.month);

      if (isPreviousMonth) {
        // For previous month transactions: generate current + next month
        await _generateRecurringInstance(
          originalTransaction,
          now.year,
          now.month,
          existingRecurrenceIds: existingCurrentMonth,
        );
        await _generateRecurringInstance(
          originalTransaction,
          nextMonth.year,
          nextMonth.month,
          existingRecurrenceIds: existingNextMonth,
        );
      } else if (isCurrentMonth) {
        // For current month transactions: only generate next month
        // (current month instance already exists as the original)
        await _generateRecurringInstance(
          originalTransaction,
          nextMonth.year,
          nextMonth.month,
          existingRecurrenceIds: existingNextMonth,
        );
      }
    }

    debugPrint('✅ checkAndGenerateRecurringTransactions: Completed');
  }

  /// Recurrence ids that already have an instance in the given month.
  Future<Set<String>> _recurrenceIdsForMonth(int year, int month) async {
    final transactions = await _dbHelper.getTransactionsByType(
      startDate: DateTime(year, month, 1),
      endDate: DateTime(year, month + 1, 0),
    );
    return transactions
        .where((t) => t.isRecurring)
        .map((t) => t.recurrenceId ?? t.id)
        .toSet();
  }

  /// Helper method to generate a recurring transaction instance for a specific
  /// month. Inserts directly into the DB — callers are responsible for
  /// reloading state afterwards, so generating N instances doesn't trigger N
  /// full recomputes and UI rebuilds.
  Future<void> _generateRecurringInstance(
    Transaction originalTransaction,
    int targetYear,
    int targetMonth, {
    Set<String>? existingRecurrenceIds,
  }) async {
    // Calculate the target day for the specified month
    // Handle edge cases like Feb 30th -> Feb 28th/29th
    int targetDay = originalTransaction.date.day;
    int lastDayOfMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    int actualDay = targetDay > lastDayOfMonth ? lastDayOfMonth : targetDay;

    DateTime targetDate = DateTime(targetYear, targetMonth, actualDay);
    final recurrenceId =
        originalTransaction.recurrenceId ?? originalTransaction.id;

    // Check if this recurrence has already been processed for this month
    final existing = existingRecurrenceIds ??
        await _recurrenceIdsForMonth(targetYear, targetMonth);

    if (existing.contains(recurrenceId)) return;
    existing.add(recurrenceId);

    // Clone and Create
    Transaction newTransaction = Transaction.createNew(
      id: newId(),
      title: originalTransaction.title,
      amount: originalTransaction.amount,
      categoryId: originalTransaction.categoryId,
      accountId: originalTransaction.accountId,
      date: targetDate,
      isExpense: originalTransaction.isExpense,
      isRecurring: true,
      recurrenceId: recurrenceId,
    );

    await _dbHelper.insertTransaction(newTransaction);
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
        .where((t) => t.isExpense && !t.isTransfer)
        .fold(0.0, (sum, t) => sum + baseAmount(t));

    _cachedPreviousMonth = prevMonth;
    notifyListeners();
  }

  Future<double> getExpenseTotalForRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _dbHelper.getTotalExpensesByPeriod(
      startDate: startDate,
      endDate: endDate,
    );
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
            !t.isTransfer &&
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day)
        .fold(0.0, (sum, t) => sum + baseAmount(t));
  }

  /// Get total income for a specific day
  double getDayIncome(DateTime day) {
    return _transactions
        .where((t) =>
            !t.isExpense &&
            !t.isTransfer &&
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day)
        .fold(0.0, (sum, t) => sum + baseAmount(t));
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
