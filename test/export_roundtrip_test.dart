import 'dart:io';

import 'package:coin_manager/db/account_db_helper.dart';
import 'package:coin_manager/db/category_db_helper.dart';
import 'package:coin_manager/db/transaction_db_helper.dart';
import 'package:coin_manager/models/transaction.dart' as model;
import 'package:coin_manager/services/export_service.dart';
import 'package:coin_manager/services/import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

/// The export dropped its id / created-at / modified-at columns to read like a
/// statement. Import matches columns by header NAME, so this guards the pair:
/// re-importing the app's own export must still find date, amount, title,
/// type, category and account — every row recognised as a duplicate, none
/// imported, nothing failed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'currencyCode': 'INR'});
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;

  Future<void> seed() async {
    final food = await DBHelper().insertCategory('Food', 'x.png', true);
    final pay = await DBHelper().insertCategory('Salary', 'x.png', false);
    final accounts = await AccountDBHelper().getAllAccounts();
    final account = accounts[0].id!;
    final second = accounts[1].id!;
    await TransactionDBHelper().insertTransactionsBatch([
      model.Transaction.createNew(
        id: 't1', title: 'Coffee', amount: 4.50, categoryId: food,
        accountId: account, date: DateTime(2026, 2, 3), isExpense: true,
      ),
      model.Transaction.createNew(
        id: 't2', title: 'Groceries', amount: 88.20, categoryId: food,
        accountId: account, date: DateTime(2026, 2, 4), isExpense: true,
      ),
      model.Transaction.createNew(
        id: 't3', title: 'Payday', amount: 5000, categoryId: pay,
        accountId: account, date: DateTime(2026, 2, 1), isExpense: false,
      ),
      model.Transaction.createTransfer(
        id: 't4', amount: 750, fromAccountId: account,
        toAccountId: second, date: DateTime(2026, 2, 5), title: 'To savings',
      ),
    ]);
  }

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('export_roundtrip');
    PathProviderPlatform.instance = _TempPathProvider(tmp.path);
    await seed();
  });

  tearDownAll(() async {
    await (await TransactionDBHelper().database).close();
    await tmp.delete(recursive: true);
  });

  test('xlsx export re-imports cleanly with the trimmed columns', () async {
    final export = await ExportService()
        .createTransactionsExcelExport(currencySymbol: '₹', currencyCode: 'INR');
    expect(export.rowCount, 4);

    final result = await ImportService().importTransactionsExcel(export.path);
    expect(result.errors, isEmpty, reason: 'every required column still found');
    expect(result.failed, 0);
    expect(result.imported, 0, reason: 'own export must not duplicate rows');
    expect(result.skippedDuplicates, 4);
  });

  test('a transfer survives the xlsx round trip as a transfer', () async {
    final export = await ExportService().createTransactionsExcelExport();
    // Import into a clean transactions table so the row is rebuilt, not
    // skipped as a duplicate.
    final db = await TransactionDBHelper().database;
    final saved = await db.query('transactions');
    await db.delete('transactions');

    final result = await ImportService().importTransactionsExcel(export.path);
    expect(result.errors, isEmpty);
    expect(result.imported, 4);

    final rows = await db.query('transactions',
        where: 'transfer_account_id IS NOT NULL');
    expect(rows.length, 1, reason: 'the transfer came back as a transfer');
    expect(rows.first['title'], 'To savings');
    expect(rows.first['amount'], 750.0);
    expect(rows.first['is_expense'], 1);
    expect(rows.first['account_id'] == rows.first['transfer_account_id'], false);

    // No junk "Unknown" category invented for the category-less transfer.
    final cats = await DBHelper().getAllCategories();
    expect(cats.where((c) => c['name'] == 'Unknown'), isEmpty);

    await db.delete('transactions');
    for (final r in saved) {
      await db.insert('transactions', r);
    }
  });

  test('a transfer between differently-priced accounts is refused', () async {
    final accounts = await AccountDBHelper().getAllAccounts();
    final foreign = accounts[1];
    foreign.currency = 'USD';
    await AccountDBHelper().updateAccount(foreign);

    final export = await ExportService().createTransactionsExcelExport();
    final db = await TransactionDBHelper().database;
    final saved = await db.query('transactions');
    await db.delete('transactions');

    final result = await ImportService().importTransactionsExcel(export.path);
    expect(result.failed, 1);
    expect(result.errors.single, contains('not supported'));
    expect(result.imported, 3, reason: 'the ordinary rows still import');

    foreign.currency = '';
    await AccountDBHelper().updateAccount(foreign);
    await db.delete('transactions');
    for (final r in saved) {
      await db.insert('transactions', r);
    }
  });

  test('csv export re-imports cleanly with the trimmed columns', () async {
    final export =
        await ExportService().createTransactionsCsvExport(currencyCode: 'INR');

    final result = await ImportService().importTransactionsCsv(export.path);
    expect(result.errors, isEmpty);
    expect(result.failed, 0);
    expect(result.imported, 0);
    expect(result.skippedDuplicates, 4);
  });
}
