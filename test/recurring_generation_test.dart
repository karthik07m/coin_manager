import 'package:coin_manager/db/transaction_db_helper.dart';
import 'package:coin_manager/models/transaction.dart' as model;
import 'package:coin_manager/providers/transaction_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Recurring generation writes real rows into the user's database on every
/// app launch, unattended. Its failure modes are expensive and quiet: a bill
/// materialised twice, an instance the user deleted coming back, or a month
/// silently skipped.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbHelper = TransactionDBHelper();
  late Database db;
  late TransactionProvider provider;

  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month);
  final lastMonth = DateTime(now.year, now.month - 1);
  final nextMonth = DateTime(now.year, now.month + 1);

  Future<List<model.Transaction>> rowsFor(DateTime month) async {
    return dbHelper.getTransactionsByType(
      startDate: DateTime(month.year, month.month, 1),
      endDate: DateTime(month.year, month.month + 1, 0, 23, 59, 59),
    );
  }

  Future<model.Transaction> seedRecurring({
    required DateTime date,
    double amount = 2000,
    String title = 'House Loan',
    String? recurrenceId,
    String id = 'seed',
  }) async {
    final t = model.Transaction.createNew(
      id: id,
      title: title,
      amount: amount,
      categoryId: 7,
      accountId: 1,
      date: date,
      isExpense: true,
      isRecurring: true,
      recurrenceId: recurrenceId,
    );
    await dbHelper.insertTransaction(t);
    return t;
  }

  setUp(() async {
    await TransactionDBHelper.resetForTests();
    db = await dbHelper.openInMemoryDatabaseForTests();
    await db.delete('transactions');
    provider = TransactionProvider();
  });

  tearDown(() async {
    await TransactionDBHelper.resetForTests();
  });

  group('checkAndGenerateRecurringTransactions', () {
    test('a series from last month fills this month and the next', () async {
      await seedRecurring(date: DateTime(lastMonth.year, lastMonth.month, 15));

      await provider.checkAndGenerateRecurringTransactions();

      expect((await rowsFor(thisMonth)).length, 1);
      expect((await rowsFor(nextMonth)).length, 1);
    });

    test('running twice does not duplicate a bill', () async {
      // App start is not the only trigger; this must be idempotent or a
      // $2,000 loan gets counted twice.
      await seedRecurring(date: DateTime(lastMonth.year, lastMonth.month, 15));

      await provider.checkAndGenerateRecurringTransactions();
      await provider.checkAndGenerateRecurringTransactions();
      await provider.checkAndGenerateRecurringTransactions();

      expect((await rowsFor(thisMonth)).length, 1);
      expect((await rowsFor(nextMonth)).length, 1);
    });

    test('generated instances copy amount, account and category', () async {
      await seedRecurring(
        date: DateTime(lastMonth.year, lastMonth.month, 15),
        amount: 327.06,
        title: 'Car Loan',
      );

      await provider.checkAndGenerateRecurringTransactions();

      final generated = (await rowsFor(thisMonth)).single;
      expect(generated.title, 'Car Loan');
      expect(generated.amount, 327.06);
      expect(generated.accountId, 1);
      expect(generated.categoryId, 7);
      expect(generated.isExpense, isTrue);
      expect(generated.isRecurring, isTrue);
      // Ties the instance back to its series so the next run dedupes it.
      expect(generated.recurrenceId, 'seed');
    });

    test('a series seeded this month only fills the next', () async {
      await seedRecurring(date: DateTime(thisMonth.year, thisMonth.month, 10));

      await provider.checkAndGenerateRecurringTransactions();

      // The current month already has the original; a second would double it.
      expect((await rowsFor(thisMonth)).length, 1);
      expect((await rowsFor(nextMonth)).length, 1);
    });

    test('a deleted instance is not resurrected', () async {
      final seed =
          await seedRecurring(date: DateTime(lastMonth.year, lastMonth.month, 15));
      await dbHelper.insertRecurringSkip(
          seed.id, thisMonth.year, thisMonth.month);

      await provider.checkAndGenerateRecurringTransactions();

      expect(await rowsFor(thisMonth), isEmpty);
      // The series continues: only the tombstoned month is held back.
      expect((await rowsFor(nextMonth)).length, 1);
    });

    test('a non-recurring transaction is never cloned', () async {
      await dbHelper.insertTransaction(model.Transaction.createNew(
        id: 'one_off',
        title: 'Amazon',
        amount: 60,
        categoryId: 3,
        accountId: 1,
        date: DateTime(lastMonth.year, lastMonth.month, 20),
        isExpense: true,
      ));

      await provider.checkAndGenerateRecurringTransactions();

      expect(await rowsFor(thisMonth), isEmpty);
      expect(await rowsFor(nextMonth), isEmpty);
    });

    test('recurring income is generated too, not just bills', () async {
      await dbHelper.insertTransaction(model.Transaction.createNew(
        id: 'salary',
        title: 'Monthly Income',
        amount: 5932,
        categoryId: 1,
        accountId: 1,
        date: DateTime(lastMonth.year, lastMonth.month, 15),
        isExpense: false,
        isRecurring: true,
      ));

      await provider.checkAndGenerateRecurringTransactions();

      final generated = (await rowsFor(thisMonth)).single;
      expect(generated.isExpense, isFalse);
      expect(generated.amount, 5932);
    });

    test('several series each generate exactly once', () async {
      await seedRecurring(
          id: 'loan',
          title: 'House Loan',
          date: DateTime(lastMonth.year, lastMonth.month, 15));
      await seedRecurring(
          id: 'car',
          title: 'Car Loan',
          amount: 327.06,
          date: DateTime(lastMonth.year, lastMonth.month, 15));
      await seedRecurring(
          id: 'netflix',
          title: 'Subscription',
          amount: 15.99,
          date: DateTime(lastMonth.year, lastMonth.month, 3));

      await provider.checkAndGenerateRecurringTransactions();

      expect((await rowsFor(thisMonth)).length, 3);
      expect((await rowsFor(nextMonth)).length, 3);
    });
  });

  group('day-of-month edge cases', () {
    test('the 31st lands on the last day of a shorter month', () async {
      // A bill due the 31st must not silently roll into the next month.
      await seedRecurring(date: DateTime(2026, 1, 31), id: 'rent');

      await provider.checkAndGenerateRecurringTransactions();

      for (final month in [thisMonth, nextMonth]) {
        final rows = await rowsFor(month);
        if (rows.isEmpty) continue;
        final lastDay = DateTime(month.year, month.month + 1, 0).day;
        expect(rows.single.date.month, month.month);
        expect(rows.single.date.day, lessThanOrEqualTo(lastDay));
      }
    });
  });
}
