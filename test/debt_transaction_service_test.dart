import 'package:coin_manager/models/debt.dart';
import 'package:coin_manager/models/debt_payment.dart';
import 'package:coin_manager/models/transaction.dart';
import 'package:coin_manager/providers/debt_provider.dart';
import 'package:coin_manager/providers/transaction_provider.dart';
import 'package:coin_manager/services/debt_transaction_service.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryTransactions extends TransactionProvider {
  final saved = <Transaction>[];
  bool failSave = false;
  @override
  Future<void> addTransaction(Transaction transaction) async {
    if (failSave) throw StateError('Storage unavailable');
    saved.add(transaction);
  }

  @override
  Future<void> deleteTransaction(String id,
          {bool deleteReceipt = true}) async =>
      saved.removeWhere((t) => t.id == id);
}

class MemoryDebts extends DebtProvider {
  Debt? debt;
  DebtPayment? payment;
  bool accept = true;
  @override
  Future<void> loadDebtsFromDB() async {}
  @override
  Debt? getDebtById(String id) => debt?.id == id ? debt : null;
  @override
  Future<bool> addDebt(Debt value) async {
    if (accept) debt = value;
    return accept;
  }

  @override
  Future<bool> recordPayment(String debtId, DebtPayment value) async {
    if (accept) payment = value;
    return accept;
  }
}

void main() {
  late MemoryTransactions transactions;
  late MemoryDebts debts;
  late DebtTransactionService service;
  Transaction entry(
          {double amount = 30, bool expense = true, bool repeat = false}) =>
      Transaction.createNew(
          id: 'tx',
          title: 'Payment',
          amount: amount,
          categoryId: 1,
          accountId: 7,
          date: DateTime(2026, 9, 8),
          isExpense: expense,
          isRecurring: repeat);
  Debt loan({bool liability = true}) => Debt.createNew(
      id: 'd',
      title: 'Loan',
      amount: 100,
      amountPaid: 20,
      debtorName: 'Sam',
      isLiability: liability);

  setUp(() {
    transactions = MemoryTransactions();
    debts = MemoryDebts();
    service = DebtTransactionService(transactions: transactions, debts: debts);
  });

  test('lending and borrowing keep original transaction and account links',
      () async {
    for (final liability in [false, true]) {
      await service.saveLoan(
          entry(amount: 100, expense: !liability), loan(liability: liability));
      expect(debts.debt!.transactionId, 'tx');
      expect(debts.debt!.accountId, 7);
      expect(debts.debt!.isLiability, liability);
    }
  });
  test('repayments and collections carry amount, date, and transaction link',
      () async {
    for (final liability in [true, false]) {
      debts.debt = loan(liability: liability);
      await service.saveRepayment(entry(expense: liability), 'd');
      expect(debts.payment!.transactionId, 'tx');
      expect(debts.payment!.amount, 30);
      expect(debts.payment!.paymentDate, DateTime(2026, 9, 8));
    }
  });
  test('overpayment is rejected before booking a transaction', () async {
    debts.debt = loan();
    await expectLater(service.saveRepayment(entry(amount: 81), 'd'),
        throwsA(isA<DebtEntryException>()));
    expect(transactions.saved, isEmpty);
  });
  test('failed debt or payment save removes the new transaction', () async {
    debts.accept = false;
    await expectLater(
        service.saveLoan(entry(amount: 100, expense: false), loan()),
        throwsA(isA<DebtEntryException>()));
    expect(transactions.saved, isEmpty);
    debts.debt = loan();
    await expectLater(service.saveRepayment(entry(), 'd'),
        throwsA(isA<DebtEntryException>()));
    expect(transactions.saved, isEmpty);
  });
  test('transaction failure never creates the debt', () async {
    transactions.failSave = true;
    await expectLater(
        service.saveLoan(entry(amount: 100, expense: false), loan()),
        throwsStateError);
    expect(debts.debt, isNull);
  });
  test('wrong direction, repeating entries, and settled debts cannot be repaid',
      () async {
    debts.debt = loan();
    for (final transaction in [entry(expense: false), entry(repeat: true)]) {
      await expectLater(service.saveRepayment(transaction, 'd'),
          throwsA(isA<DebtEntryException>()));
    }
    debts.debt!.amountPaid = 100;
    await expectLater(service.saveRepayment(entry(), 'd'),
        throwsA(isA<DebtEntryException>()));
    expect(transactions.saved, isEmpty);
  });
}
