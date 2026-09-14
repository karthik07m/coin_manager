import 'package:coin_manager/db/transaction_db_helper.dart';
import 'package:coin_manager/models/transaction.dart';
import 'package:coin_manager/providers/transaction_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Database db;

  setUp(() async {
    await TransactionDBHelper.resetForTests();
    db = await TransactionDBHelper().openInMemoryDatabaseForTests();
  });
  tearDown(TransactionDBHelper.resetForTests);

  Future<void> insert(String id, DateTime date, double amount,
      {bool expense = true, int? transferAccountId, int accountId = 1}) async {
    final transaction = Transaction.createNew(
        id: id,
        title: id,
        amount: amount,
        categoryId: 1,
        accountId: accountId,
        date: date,
        isExpense: expense);
    transaction.transferAccountId = transferAccountId;
    await db.insert('transactions', transaction.toMap());
  }

  test(
      'April-start totals span two years, convert amounts, and exclude transfers/income',
      () async {
    await insert('before', DateTime(2025, 3, 31, 23, 59, 59), 999);
    await insert('april', DateTime(2025, 4, 1), 100);
    await insert('january', DateTime(2026, 1, 15), 10, accountId: 2);
    await insert(
        'last-instant', DateTime(2026, 3, 31, 23, 59, 59, 999, 999), 30);
    await insert('after', DateTime(2026, 4, 1), 999);
    await insert('income', DateTime(2025, 4, 10), 999, expense: false);
    await insert('transfer', DateTime(2025, 4, 15), 999, transferAccountId: 2);
    final provider = TransactionProvider()
      ..baseAmountResolver =
          (accountId, amount) => accountId == 2 ? amount * 80 : amount;
    addTearDown(provider.dispose);
    final totals = await provider.monthlyExpenseTotals(2025, startMonth: 4);
    expect(totals[0], 100);
    expect(totals[9], 800);
    expect(totals[11], 30);
    expect(totals.fold<double>(0, (a, b) => a + b), 930);
  });

  test('January default preserves calendar-year totals', () async {
    await insert('old', DateTime(2025, 12, 31), 999);
    await insert('january', DateTime(2026, 1, 1), 40);
    await insert('december', DateTime(2026, 12, 31, 23, 59, 59, 500), 60);
    await insert('next', DateTime(2027, 1, 1), 999);
    final provider = TransactionProvider();
    addTearDown(provider.dispose);
    final totals = await provider.monthlyExpenseTotals(2026);
    expect(totals[0], 40);
    expect(totals[11], 60);
    expect(totals.fold<double>(0, (a, b) => a + b), 100);
  });
}
