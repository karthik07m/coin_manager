import 'package:flutter/material.dart';
import '../db/debt_db_helper.dart';
import '../models/debt.dart';
import '../models/debt_payment.dart';

class DebtProvider with ChangeNotifier {
  List<Debt> _debts = [];
  final DebtDBHelper _dbHelper = DebtDBHelper();

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
      // Update statuses for all debts
      for (var debt in _debts) {
        debt.updateStatus();
        if (debt.status != DebtStatus.values[debt.status.index]) {
          await _dbHelper.updateDebt(debt);
        }
      }
      notifyListeners();
    } catch (e) {
      _debts = [];
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

  // Add a new debt
  Future<bool> addDebt(Debt debt) async {
    try {
      final result = await _dbHelper.insertDebt(debt);
      if (result != -1) {
        _debts.add(debt);
        notifyListeners();
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
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Delete a debt
  Future<bool> deleteDebt(String id) async {
    try {
      final result = await _dbHelper.deleteDebt(id);
      if (result != -1) {
        _debts.removeWhere((debt) => debt.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Record a payment for a debt
  Future<bool> recordPayment(String debtId, DebtPayment payment) async {
    try {
      // Insert payment record
      final paymentResult = await _dbHelper.insertPayment(payment);
      if (paymentResult == -1) return false;

      // Get the debt
      final debt = getDebtById(debtId);
      if (debt == null) return false;

      // Update debt's amount paid
      debt.amountPaid += payment.amount;
      debt.updateStatus();
      debt.modifiedOn = DateTime.now();

      // Save updated debt
      final debtResult = await _dbHelper.updateDebt(debt);
      if (debtResult != -1) {
        notifyListeners();
        return true;
      }
      return false;
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

  // Mark debt as fully paid
  Future<bool> markAsPaid(String debtId) async {
    try {
      final debt = getDebtById(debtId);
      if (debt == null) return false;

      // If there's remaining amount, record it as a payment
      final remaining = debt.getRemainingAmount();
      if (remaining > 0) {
        final payment = DebtPayment.createNew(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          debtId: debtId,
          amount: remaining,
          paymentDate: DateTime.now(),
          notes: 'Final payment',
        );
        return await recordPayment(debtId, payment);
      } else {
        debt.status = DebtStatus.paid;
        debt.modifiedOn = DateTime.now();
        return await updateDebt(debt);
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
