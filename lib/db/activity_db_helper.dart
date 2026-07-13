import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/activity_log.dart';
import 'transaction_db_helper.dart';

/// Persists the app's activity/audit log. Shares the single transactions.db
/// via TransactionDBHelper (the table is created/migrated there).
class ActivityDBHelper {
  static final ActivityDBHelper _instance = ActivityDBHelper._internal();
  factory ActivityDBHelper() => _instance;
  ActivityDBHelper._internal();

  static const String tableName = 'activity_log';

  /// Cap the log so it can't grow without bound; oldest rows are pruned.
  static const int _maxEntries = 1000;

  Future<Database> get _database async => TransactionDBHelper().database;

  Future<void> insert(ActivityLog log) async {
    final db = await _database;
    await db.insert(tableName, log.toMap()..remove('id'));
    // Prune anything beyond the newest _maxEntries rows.
    await db.rawDelete(
      '''
      DELETE FROM $tableName
      WHERE id NOT IN (
        SELECT id FROM $tableName ORDER BY id DESC LIMIT ?
      )
      ''',
      [_maxEntries],
    );
  }

  Future<List<ActivityLog>> getAll() async {
    final db = await _database;
    final rows = await db.query(tableName, orderBy: 'id DESC');
    return rows.map((r) => ActivityLog.fromMap(r)).toList();
  }

  Future<void> clearAll() async {
    final db = await _database;
    try {
      await db.delete(tableName);
    } catch (e) {
      debugPrint('ActivityDBHelper clearAll error: $e');
    }
  }
}
