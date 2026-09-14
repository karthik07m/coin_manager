import 'dart:io';

import 'package:coin_manager/db/account_db_helper.dart';
import 'package:coin_manager/db/transaction_db_helper.dart';
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

/// A CSV row naming an unknown account used to land in the default account,
/// silently corrupting its balance. It must create the account instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'currencyCode': 'INR'});
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('import_test');
    PathProviderPlatform.instance = _TempPathProvider(tmp.path);
  });

  tearDown(() async {
    await (await TransactionDBHelper().database).close();
    await tmp.delete(recursive: true);
  });

  test('unknown account name is created, not folded into the default',
      () async {
    final csv = File('${tmp.path}/in.csv');
    await csv.writeAsString(
      'Date,Amount,Title,Type,Category,Account\n'
      '2026-01-05,25.00,Coffee,Expense,Food,Amex Gold\n'
      '2026-01-06,40.00,Lunch,Expense,Food,Amex Gold\n'
      '2026-01-07,10.00,Bus,Expense,Travel,\n',
    );

    final before = await AccountDBHelper().getAllAccounts();
    final defaultId = before.first.id!;
    expect(before.any((a) => a.name == 'Amex Gold'), isFalse);

    final result = await ImportService().importTransactionsCsv(csv.path);
    expect(result.errors, isEmpty);
    expect(result.imported, 3);

    final after = await AccountDBHelper().getAllAccounts();
    final created = after.where((a) => a.name == 'Amex Gold');
    expect(created.length, 1, reason: 'created exactly once for two rows');

    final db = await TransactionDBHelper().database;
    final rows = await db.query('transactions', orderBy: 'date ASC');
    expect(rows[0]['account_id'], created.first.id);
    expect(rows[1]['account_id'], created.first.id);
    // Blank account cell still falls back to the default account.
    expect(rows[2]['account_id'], defaultId);
  });
}
