import '../models/debt.dart';
import '../models/debt_payment.dart';
import '../models/transaction.dart';
import '../providers/debt_provider.dart';
import '../providers/transaction_provider.dart';
import '../utilities/id_generator.dart';

class DebtEntryException implements Exception {
  final String message;
  const DebtEntryException(this.message);
}

/// Coordinates the transaction form's loan and repayment entries. The two
/// stores are separate, so undo a newly booked transaction if linking fails.
class DebtTransactionService {
  final TransactionProvider transactions;
  final DebtProvider debts;

  DebtTransactionService({required this.transactions, required this.debts});

  Future<String> saveLoan(Transaction transaction, Debt debt) async {
    if (transaction.isRecurring ||
        transaction.isTransfer ||
        transaction.isExpense == debt.isLiability ||
        !transaction.amount.isFinite ||
        transaction.amount <= 0 ||
        transaction.amount != debt.amount) {
      throw const DebtEntryException(
          'Check the loan amount and transaction type.');
    }
    debt.transactionId = transaction.id;
    debt.accountId = transaction.accountId;
    await transactions.addTransaction(transaction);
    if (!await debts.addDebt(debt)) {
      await transactions.deleteTransaction(transaction.id,
          deleteReceipt: false);
      throw const DebtEntryException(
          'Could not create the debt. Please try again.');
    }
    return debt.id;
  }

  Future<String> saveRepayment(Transaction transaction, String debtId) async {
    // Reload so the picker selection cannot overpay a balance changed elsewhere.
    await debts.loadDebtsFromDB();
    final debt = debts.getDebtById(debtId);
    if (debt == null || debt.getRemainingAmount() <= 0.005) {
      throw const DebtEntryException(
          'This debt is no longer available for repayment.');
    }
    if (transaction.isRecurring ||
        transaction.isTransfer ||
        transaction.isExpense != debt.isLiability ||
        !transaction.amount.isFinite ||
        transaction.amount <= 0) {
      throw const DebtEntryException(
          'Check the repayment amount and transaction type.');
    }
    if (transaction.amount > debt.getRemainingAmount() + 0.005) {
      throw const DebtEntryException(
          'Repayment cannot exceed the remaining debt balance.');
    }
    await transactions.addTransaction(transaction);
    final ok = await debts.recordPayment(
        debtId,
        DebtPayment.createNew(
          id: newId(),
          debtId: debtId,
          amount: transaction.amount,
          paymentDate: transaction.date,
          notes: transaction.title.trim(),
          transactionId: transaction.id,
        ));
    if (!ok) {
      await transactions.deleteTransaction(transaction.id,
          deleteReceipt: false);
      throw const DebtEntryException(
          'Could not record the repayment. Please try again.');
    }
    return debtId;
  }
}
