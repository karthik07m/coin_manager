import 'package:coin_manager/db/account_db_helper.dart';
import 'package:coin_manager/db/transaction_db_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Balance math against a real SQLite database.
///
/// These cover the layer that actually holds the user's money figures. The
/// pure-Dart tests could never have caught the bug where a current balance
/// silently included next month's scheduled recurring rows.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final accountsDb = AccountDBHelper();
  late Database db;

  const chase = 1;
  const card = 2;
  const savings = 3;

  Future<void> insertAccount(int id, String name, double opening) async {
    await db.insert('accounts', {
      'id': id,
      'name': name,
      'icon': 'bank',
      'color': 0,
      'initial_balance': opening,
      'is_default': 0,
      'created_on': DateTime(2026, 1, 1).toIso8601String(),
      'modified_on': DateTime(2026, 1, 1).toIso8601String(),
    });
  }

  Future<void> insertTransaction({
    required String id,
    required double amount,
    required bool isExpense,
    required DateTime date,
    int accountId = chase,
    int? transferAccountId,
  }) async {
    await db.insert('transactions', {
      'id': id,
      'title': id,
      'amount': amount,
      'category_id': 1,
      'account_id': accountId,
      'transfer_account_id': transferAccountId,
      'date': date.toIso8601String(),
      'is_expense': isExpense ? 1 : 0,
      'is_recurring': 0,
      'created_on': date.toIso8601String(),
      'modified_on': date.toIso8601String(),
    });
  }

  DateTime daysFromNow(int days) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: days));
  }

  setUp(() async {
    await TransactionDBHelper.resetForTests();
    db = await TransactionDBHelper().openInMemoryDatabaseForTests();
    await db.delete('accounts');
    await insertAccount(chase, 'Chase', 1000);
    await insertAccount(card, 'Card', 0);
    await insertAccount(savings, 'Savings', 500);
  });

  tearDown(() async {
    await TransactionDBHelper.resetForTests();
  });

  group('calculateAccountBalance', () {
    test('opening balance plus income minus expenses', () async {
      await insertTransaction(
          id: 'a', amount: 200, isExpense: false, date: daysFromNow(-5));
      await insertTransaction(
          id: 'b', amount: 50, isExpense: true, date: daysFromNow(-2));

      expect(await accountsDb.calculateAccountBalance(chase), 1150);
    });

    test('scheduled future transactions do not count yet', () async {
      // The regression: next month's recurring instance is a real row, but
      // the money has not moved, and no list in the app shows it.
      await insertTransaction(
          id: 'past', amount: 100, isExpense: true, date: daysFromNow(-1));
      await insertTransaction(
          id: 'future', amount: 400, isExpense: true, date: daysFromNow(20));

      expect(await accountsDb.calculateAccountBalance(chase), 900);
    });

    test('future income is not spendable either', () async {
      await insertTransaction(
          id: 'salary', amount: 5000, isExpense: false, date: daysFromNow(14));

      expect(await accountsDb.calculateAccountBalance(chase), 1000);
    });

    test('a transaction dated today counts', () async {
      await insertTransaction(
          id: 'today', amount: 75, isExpense: true, date: daysFromNow(0));

      expect(await accountsDb.calculateAccountBalance(chase), 925);
    });

    test('transfers move money between both sides', () async {
      await insertTransaction(
        id: 'transfer',
        amount: 300,
        isExpense: true,
        date: daysFromNow(-1),
        accountId: chase,
        transferAccountId: savings,
      );

      expect(await accountsDb.calculateAccountBalance(chase), 700);
      expect(await accountsDb.calculateAccountBalance(savings), 800);
    });

    test('a transfer is never double counted as an expense', () async {
      await insertTransaction(
        id: 'transfer',
        amount: 300,
        isExpense: true,
        date: daysFromNow(-1),
        accountId: chase,
        transferAccountId: savings,
      );

      // 1000 - 300 once, not twice.
      expect(await accountsDb.calculateAccountBalance(chase), 700);
    });

    test('liabilities invert: spending increases what is owed', () async {
      await insertTransaction(
          id: 'buy',
          amount: 250,
          isExpense: true,
          date: daysFromNow(-3),
          accountId: card);
      await insertTransaction(
          id: 'payment',
          amount: 100,
          isExpense: false,
          date: daysFromNow(-1),
          accountId: card);

      expect(
        await accountsDb.calculateAccountBalance(card, isLiability: true),
        150,
      );
    });

    test('as-of reconstructs a historical balance', () async {
      await insertTransaction(
          id: 'old', amount: 100, isExpense: true, date: daysFromNow(-10));
      await insertTransaction(
          id: 'recent', amount: 200, isExpense: true, date: daysFromNow(-1));

      final asOf = await accountsDb.calculateAccountBalanceAsOf(
        chase,
        daysFromNow(-5),
      );

      expect(asOf, 900);
      expect(await accountsDb.calculateAccountBalance(chase), 700);
    });

    test('an unknown account is zero, not a crash', () async {
      expect(await accountsDb.calculateAccountBalance(999), 0);
    });
  });
}
