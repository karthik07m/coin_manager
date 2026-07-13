import 'package:flutter/foundation.dart';
import '../db/activity_db_helper.dart';
import '../models/activity_log.dart';

/// Central, fire-and-forget audit logger. Every data mutation in the app
/// (transactions, transfers, accounts, categories, budgets, goals) routes a
/// one-line entry here. Failures are swallowed — logging must never break the
/// operation it is recording.
class ActivityLogger {
  static final ActivityLogger _instance = ActivityLogger._internal();
  factory ActivityLogger() => _instance;
  ActivityLogger._internal();

  final ActivityDBHelper _db = ActivityDBHelper();

  Future<void> log(
    ActivityAction action,
    ActivityEntity entity,
    String title, {
    double? amount,
  }) async {
    try {
      await _db.insert(ActivityLog(
        action: action,
        entity: entity,
        title: title.trim().isEmpty ? entity.label : title.trim(),
        amount: amount,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('ActivityLogger failed: $e');
    }
  }

  Future<void> created(ActivityEntity entity, String title, {double? amount}) =>
      log(ActivityAction.created, entity, title, amount: amount);

  Future<void> updated(ActivityEntity entity, String title, {double? amount}) =>
      log(ActivityAction.updated, entity, title, amount: amount);

  Future<void> deleted(ActivityEntity entity, String title, {double? amount}) =>
      log(ActivityAction.deleted, entity, title, amount: amount);
}
