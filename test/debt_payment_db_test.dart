import 'package:coin_manager/db/debt_db_helper.dart';
import 'package:coin_manager/models/debt.dart';
import 'package:coin_manager/models/debt_payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final helper = DebtDBHelper();
  late Database db;

  DebtPayment payment(double amount,
          {String id = 'p',
          String debtId = 'd',
          String? transactionId = 'tx'}) =>
      DebtPayment.createNew(
          id: id,
          debtId: debtId,
          amount: amount,
          paymentDate: DateTime(2026, 9, 8),
          transactionId: transactionId);

  setUp(() async {
    db = await helper.openInMemoryDatabaseForTests();
    await helper.insertDebt(Debt.createNew(
        id: 'd',
        title: 'Loan',
        amount: 100,
        amountPaid: 20,
        debtorName: 'Sam',
        isLiability: true,
        dueDate: DateTime(2020),
        transactionId: 'original-loan'));
  });
  tearDown(DebtDBHelper.resetForTests);

  test('repaying an overdue debt updates history and remaining balance',
      () async {
    expect(await helper.recordPayment(payment(30)), isTrue);
    final debt = (await helper.getDebtById('d'))!;
    expect(debt.getRemainingAmount(), 50);
    expect(debt.status, DebtStatus.overdue);
    expect((await helper.getPaymentsByDebtId('d')).single.transactionId, 'tx');
  });

  test('full repayment closes debt', () async {
    expect(await helper.recordPayment(payment(80)), isTrue);
    expect((await helper.getDebtById('d'))!.status, DebtStatus.paid);
  });

  test('overpayment and invalid amounts leave both tables unchanged', () async {
    for (final amount in [80.01, 0.0, -1.0, double.nan, double.infinity]) {
      expect(await helper.recordPayment(payment(amount)), isFalse);
    }
    expect((await helper.getDebtById('d'))!.amountPaid, 20);
    expect(await helper.getPaymentsByDebtId('d'), isEmpty);
  });

  test('links name the loan booking and each repayment', () async {
    expect(await helper.recordPayment(payment(30)), isTrue);
    final links = {
      for (final row in await helper.getTransactionLinks())
        row['transaction_id']: row
    };
    expect(links['original-loan']!['is_payment'], 0);
    expect(links['tx']!['is_payment'], 1);
    expect(links['tx']!['debt_id'], 'd');
    expect(links['tx']!['debtor_name'], 'Sam');
    expect(links.length, 2);
  });

  test('deleting a linked transaction reverses the repayment or unbooks the loan',
      () async {
    expect(await helper.recordPayment(payment(30)), isTrue);
    await helper.detachTransaction('tx');
    var debt = (await helper.getDebtById('d'))!;
    expect(debt.amountPaid, 20);
    expect(await helper.getPaymentsByDebtId('d'), isEmpty);
    expect(debt.transactionId, 'original-loan');
    await helper.detachTransaction('original-loan');
    debt = (await helper.getDebtById('d'))!;
    expect(debt.transactionId, isNull);
    expect(debt.amount, 100);
    await helper.detachTransaction('never-linked'); // no-op, no throw
    expect(await helper.getTransactionLinks(), isEmpty);
  });

  test('a transaction cannot pay two debts or count twice', () async {
    await helper.insertDebt(Debt.createNew(
        id: 'other',
        title: 'Other',
        amount: 100,
        debtorName: 'Jo',
        isLiability: true));
    expect(await helper.recordPayment(payment(10)), isTrue);
    expect(await helper.recordPayment(payment(10, id: 'again')), isFalse);
    expect(
        await helper.recordPayment(payment(10, id: 'another', debtId: 'other')),
        isFalse);
    expect((await helper.getDebtById('d'))!.amountPaid, 30);
    expect((await helper.getDebtById('other'))!.amountPaid, 0);
  });

  test('original loan transaction cannot also be a repayment', () async {
    expect(
        await helper.recordPayment(payment(10, transactionId: 'original-loan')),
        isFalse);
    expect(await helper.getPaymentsByDebtId('d'), isEmpty);
  });

  test('independent manual payments without transactions remain allowed',
      () async {
    expect(
        await helper.recordPayment(payment(10, transactionId: null)), isTrue);
    expect(
        await helper
            .recordPayment(payment(10, id: 'second', transactionId: null)),
        isTrue);
    expect((await helper.getDebtById('d'))!.amountPaid, 40);
  });

  test('database failure rolls back payment insertion and debt balance',
      () async {
    await db.execute("CREATE TRIGGER reject_update BEFORE UPDATE ON debts "
        "BEGIN SELECT RAISE(ABORT, 'test failure'); END");
    await expectLater(
        helper.recordPayment(payment(10)), throwsA(isA<DatabaseException>()));
    expect(await helper.getPaymentsByDebtId('d'), isEmpty);
    expect((await helper.getDebtById('d'))!.amountPaid, 20);
  });

  test('concurrent payments cannot overpay using a stale balance', () async {
    final results = await Future.wait([
      helper.recordPayment(payment(50)),
      helper.recordPayment(payment(50, id: 'second', transactionId: 'tx2')),
    ]);
    expect(results.where((ok) => ok).length, 1);
    expect((await helper.getDebtById('d'))!.amountPaid, 70);
  });
}
