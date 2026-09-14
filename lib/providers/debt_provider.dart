import 'package:flutter/material.dart';
import '../db/debt_db_helper.dart';
import '../models/activity_log.dart';
import '../providers/transaction_provider.dart';
import '../services/activity_logger.dart';
import '../services/bill_reminder_scheduler.dart';
import '../utilities/id_generator.dart';
import '../models/debt.dart';
import '../models/debt_payment.dart';

/// Why a transaction exists in the Debt Tracker: the debt it belongs to and a
/// human label such as "Lent to Ravi" or "Repaid to Ravi".
class DebtLink {
  final String debtId;
  final String label;
  const DebtLink({required this.debtId, required this.label});
}

class DebtProvider with ChangeNotifier {
  List<Debt> _debts = [];
  Map<String, DebtLink> _links = {};
  final DebtDBHelper _dbHelper = DebtDBHelper();

  /// The debt a transaction was booked for, or null for a plain transaction.
  DebtLink? linkFor(String transactionId) => _links[transactionId];

  Future<void> _refreshLinks() async {
    final rows = await _dbHelper.getTransactionLinks();
    _links = {
      for (final row in rows)
        row['transaction_id'] as String: DebtLink(
          debtId: row['debt_id'] as String,
          label: _linkLabel(
            debtorName: row['debtor_name'] as String,
            isLiability: row['is_liability'] == 1,
            isPayment: row['is_payment'] == 1,
          ),
        ),
    };
  }

  static String _linkLabel(
      {required String debtorName,
      required bool isLiability,
      required bool isPayment}) {
    if (isPayment) {
      return isLiability ? 'Repaid to $debtorName' : 'Repayment from $debtorName';
    }
    return isLiability ? 'Borrowed from $debtorName' : 'Lent to $debtorName';
  }

  List<Debt> get debts => [..._debts];

  List<Debt> get liabilities =>
      _debts.where((debt) => debt.isLiability).toList();

  List<Debt> get receivables =>
      _debts.where((debt) => !debt.isLiability).toList();

  List<Debt> get activeDebts =>
      _debts.where((debt) => debt.status == DebtStatus.active).toList();

  List<Debt> get overdueDebts =>
      _debts.where((debt) => debt.status == DebtStatus.overdue).toList();

  List<Debt> get paidDebts =>
      _debts.where((debt) => debt.status == DebtStatus.paid).toList();

  Future<Set<String>> getLinkedTransactionIds() =>
      _dbHelper.getLinkedTransactionIds();

  double get totalLiabilities {
    return _debts
        .where((debt) => debt.isLiability && debt.status != DebtStatus.paid)
        .fold(0.0, (sum, debt) => sum + debt.getRemainingAmount());
  }

  double get totalReceivables {
    return _debts
        .where((debt) => !debt.isLiability && debt.status != DebtStatus.paid)
        .fold(0.0, (sum, debt) => sum + debt.getRemainingAmount());
  }

  double get netPosition => totalReceivables - totalLiabilities;

  int get activeDebtCount => activeDebts.length;

  int get overdueDebtCount => overdueDebts.length;

  // Load all debts from database
  Future<void> loadDebtsFromDB() async {
    try {
      _debts = await _dbHelper.getDebts();
      // Recompute status (e.g. active -> overdue) and persist any changes
      for (var debt in _debts) {
        final previousStatus = debt.status;
        debt.updateStatus();
        if (debt.status != previousStatus) {
          debt.modifiedOn = DateTime.now();
          await _dbHelper.updateDebt(debt);
        }
      }
      await _refreshLinks();
      notifyListeners();
    } catch (e) {
      _debts = [];
      _links = {};
      notifyListeners();
    }
  }

  // Get debt by ID
  Debt? getDebtById(String id) {
    try {
      return _debts.firstWhere((debt) => debt.id == id);
    } catch (e) {
      return null;
    }
  }

  // Refresh due-date reminders after any change that affects debts.
  // Fire-and-forget: no-ops when bill reminders are disabled in settings.
  void _refreshReminders() {
    BillReminderScheduler().reschedule();
  }

  // Add a new debt
  Future<bool> addDebt(Debt debt) async {
    try {
      final result = await _dbHelper.insertDebt(debt);
      if (result != -1) {
        _debts.add(debt);
        await _refreshLinks();
        notifyListeners();
        _refreshReminders();
        ActivityLogger().created(
          ActivityEntity.debt,
          debt.title,
          amount: debt.amount,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Update an existing debt
  Future<bool> updateDebt(Debt debt) async {
    try {
      final result = await _dbHelper.updateDebt(debt);
      if (result != -1) {
        final index = _debts.indexWhere((d) => d.id == debt.id);
        if (index != -1) {
          _debts[index] = debt;
          await _refreshLinks();
          notifyListeners();
          _refreshReminders();
          ActivityLogger().updated(
            ActivityEntity.debt,
            debt.title,
            amount: debt.amount,
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Delete a debt and cascade-clean all linked data.
  //
  // When [transactionProvider] is supplied the method also deletes:
  //   • Every settlement transaction linked to the debt's payments.
  //   • The initial loan-booking transaction linked to the debt itself.
  // This keeps account balances accurate after a debt is removed.
  Future<bool> deleteDebt(
    String id, {
    TransactionProvider? transactionProvider,
  }) async {
    try {
      final debt = getDebtById(id);
      final title = debt?.title ?? 'Debt';
      final amount = debt?.amount ?? 0.0;

      // Clean up linked transactions before deleting the debt row.
      if (transactionProvider != null) {
        // 1. Delete settlement transactions linked to each payment.
        final payments = await _dbHelper.getPaymentsByDebtId(id);
        for (final payment in payments) {
          if (payment.transactionId != null) {
            await transactionProvider.deleteTransaction(payment.transactionId!);
          }
        }
        // 2. Delete the loan-booking transaction linked to the debt.
        if (debt?.transactionId != null) {
          await transactionProvider.deleteTransaction(debt!.transactionId!);
        }
      }

      final result = await _dbHelper.deleteDebt(id);
      if (result != -1) {
        _debts.removeWhere((debt) => debt.id == id);
        await _refreshLinks();
        notifyListeners();
        _refreshReminders();
        ActivityLogger().deleted(
          ActivityEntity.debt,
          title,
          amount: amount,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Delete a single payment and recalculate the parent debt's balance.
  //
  // When [transactionProvider] is supplied the linked settlement
  // transaction (if any) is deleted as well, keeping account balances
  // accurate.
  Future<bool> deletePayment(
    String paymentId, {
    TransactionProvider? transactionProvider,
  }) async {
    try {
      // Fetch the payment so we know which debt to adjust.
      final payment = await _dbHelper.getPaymentById(paymentId);
      if (payment == null) return false;

      // Delete the payment row.
      final result = await _dbHelper.deletePayment(paymentId);
      if (result == -1) return false;

      // Recalculate the parent debt's amountPaid & status.
      final debt = getDebtById(payment.debtId);
      if (debt != null) {
        debt.amountPaid =
            (debt.amountPaid - payment.amount).clamp(0, double.infinity);
        debt.updateStatus();
        debt.modifiedOn = DateTime.now();
        await _dbHelper.updateDebt(debt);
      }

      // Delete the linked settlement transaction if requested — after the
      // payment row is gone, so the transaction delete hook has nothing
      // left to reverse.
      if (transactionProvider != null && payment.transactionId != null) {
        await transactionProvider.deleteTransaction(payment.transactionId!);
      }

      await _refreshLinks();
      notifyListeners();
      _refreshReminders();
      ActivityLogger().deleted(
        ActivityEntity.debt,
        'Payment of ${payment.amount.toStringAsFixed(2)}',
        amount: payment.amount,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // Record a payment for a debt
  Future<bool> recordPayment(String debtId, DebtPayment payment) async {
    try {
      if (payment.debtId != debtId) return false;
      final ok = await _dbHelper.recordPayment(payment);
      if (!ok) return false;
      final updated = await _dbHelper.getDebtById(debtId);
      if (updated != null) {
        final index = _debts.indexWhere((d) => d.id == debtId);
        if (index == -1) {
          _debts.add(updated);
        } else {
          _debts[index] = updated;
        }
      }
      await _refreshLinks();
      notifyListeners();
      _refreshReminders();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get payment history for a debt
  Future<List<DebtPayment>> getPaymentHistory(String debtId) async {
    try {
      return await _dbHelper.getPaymentsByDebtId(debtId);
    } catch (e) {
      return [];
    }
  }

  // Mark debt as fully paid. [transactionId] links the settlement to a
  // transaction the caller created for it, if any.
  Future<bool> markAsPaid(String debtId, {String? transactionId}) async {
    try {
      final debt = getDebtById(debtId);
      if (debt == null) return false;

      // If there's remaining amount, record it as a payment
      final remaining = debt.getRemainingAmount();
      if (remaining > 0) {
        final payment = DebtPayment.createNew(
          id: newId(),
          debtId: debtId,
          amount: remaining,
          paymentDate: DateTime.now(),
          notes: 'Final payment',
          transactionId: transactionId,
        );
        final ok = await recordPayment(debtId, payment);
        if (ok) {
          ActivityLogger().updated(
            ActivityEntity.debt,
            '${debt.title} marked as paid',
            amount: debt.amount,
          );
        }
        return ok;
      } else {
        debt.status = DebtStatus.paid;
        debt.modifiedOn = DateTime.now();
        final ok = await updateDebt(debt);
        if (ok) {
          ActivityLogger().updated(
            ActivityEntity.debt,
            '${debt.title} marked as paid',
            amount: debt.amount,
          );
        }
        return ok;
      }
    } catch (e) {
      return false;
    }
  }

  // Get debts by type
  Future<List<Debt>> getDebtsByType({required bool isLiability}) async {
    try {
      return await _dbHelper.getDebtsByType(isLiability: isLiability);
    } catch (e) {
      return [];
    }
  }

  // Filter debts by status
  List<Debt> filterByStatus(DebtStatus status) {
    return _debts.where((debt) => debt.status == status).toList();
  }

  // Filter debts by type and status
  List<Debt> filterByTypeAndStatus({
    required bool isLiability,
    DebtStatus? status,
  }) {
    var filtered = _debts.where((debt) => debt.isLiability == isLiability);
    if (status != null) {
      filtered = filtered.where((debt) => debt.status == status);
    }
    return filtered.toList();
  }

  // Get upcoming payments (debts due in next 7 days)
  List<Debt> getUpcomingPayments() {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));
    return _debts
        .where((debt) =>
            debt.status == DebtStatus.active &&
            debt.dueDate != null &&
            debt.dueDate!.isAfter(now) &&
            debt.dueDate!.isBefore(nextWeek))
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }
}
