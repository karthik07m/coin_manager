import 'dart:io';

import 'package:coin_manager/db/activity_db_helper.dart';
import 'package:coin_manager/db/transaction_db_helper.dart';
import 'package:coin_manager/models/activity_log.dart';
import 'package:coin_manager/models/transaction.dart' as model;
import 'package:coin_manager/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _P extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _P(this.d);
  final String d;
  @override
  Future<String?> getApplicationDocumentsPath() async => d;
  @override
  Future<String?> getTemporaryPath() async => d;
}

/// The backup serialises tables one by one, so any table not named in
/// _collectAllData is silently dropped on restore. recurring_skips was, which
/// meant every recurring instance the user had deleted came back as a
/// duplicate after restoring.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'currencyCode': 'INR'});
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('backup_roundtrip');
    PathProviderPlatform.instance = _P(tmp.path);
  });

  tearDownAll(() async {
    await (await TransactionDBHelper().database).close();
    await tmp.delete(recursive: true);
  });

  test('a deleted recurring instance stays deleted across a restore', () async {
    final db = TransactionDBHelper();
    await db.insertTransaction(model.Transaction.createNew(
      id: 'rent', title: 'Rent', amount: 1200, categoryId: 1, accountId: 1,
      date: DateTime(2026, 3, 1), isExpense: true, isRecurring: true,
    ));
    // The user deleted March's instance of this series.
    await db.insertRecurringSkip('rent', 2026, 3);
    await ActivityDBHelper().insert(ActivityLog(
      action: ActivityAction.deleted,
      entity: ActivityEntity.transaction,
      title: 'Rent',
      amount: 1200,
      timestamp: DateTime(2026, 3, 2),
    ));
    expect(await db.isRecurringSkipped('rent', 2026, 3), isTrue);

    final path = await BackupService().createBackup(customName: 'rt');

    // Simulate restoring onto a device that never knew about that deletion.
    final raw = await db.database;
    await raw.delete('recurring_skips');
    await raw.delete('activity_log');
    expect(await db.isRecurringSkipped('rent', 2026, 3), isFalse);

    await BackupService().restoreBackup(path);

    expect(await db.isRecurringSkipped('rent', 2026, 3), isTrue,
        reason: 'the tombstone must survive the round trip');
    expect((await raw.query('activity_log')).length, 1);
    expect((await raw.query('transactions')).length, 1);
  });
}
