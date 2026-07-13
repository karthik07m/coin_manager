import 'package:flutter/material.dart';

/// What happened to a record: created, updated, or deleted.
enum ActivityAction {
  created('created', 'Added'),
  updated('updated', 'Updated'),
  deleted('deleted', 'Removed');

  final String key;
  final String label;
  const ActivityAction(this.key, this.label);

  static ActivityAction fromKey(String? key) =>
      ActivityAction.values.firstWhere((a) => a.key == key,
          orElse: () => ActivityAction.updated);
}

/// Which kind of record the activity touched. Carries its own icon so the
/// history feed can render without a lookup table.
enum ActivityEntity {
  transaction('transaction', 'Transaction', Icons.receipt_long_rounded),
  transfer('transfer', 'Transfer', Icons.swap_horiz_rounded),
  account('account', 'Account', Icons.account_balance_wallet_rounded),
  category('category', 'Category', Icons.category_rounded),
  budget('budget', 'Budget', Icons.pie_chart_rounded),
  goal('goal', 'Goal', Icons.flag_rounded);

  final String key;
  final String label;
  final IconData icon;
  const ActivityEntity(this.key, this.label, this.icon);

  static ActivityEntity fromKey(String? key) =>
      ActivityEntity.values.firstWhere((e) => e.key == key,
          orElse: () => ActivityEntity.transaction);
}

/// A single audit-trail entry: "who did what, when" for every data change in
/// the app. Read-only once written.
class ActivityLog {
  final int? id;
  final ActivityAction action;
  final ActivityEntity entity;

  /// Human-readable name of the affected record (transaction title, account
  /// name, "Chase → Amazon Visa" for a transfer, category name, etc.).
  final String title;

  /// Optional monetary value, formatted with the user's currency at display.
  final double? amount;
  final DateTime timestamp;

  ActivityLog({
    this.id,
    required this.action,
    required this.entity,
    required this.title,
    this.amount,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'action': action.key,
        'entity': entity.key,
        'title': title,
        'amount': amount,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    final amt = map['amount'];
    return ActivityLog(
      id: map['id'] as int?,
      action: ActivityAction.fromKey(map['action'] as String?),
      entity: ActivityEntity.fromKey(map['entity'] as String?),
      title: (map['title'] ?? '') as String,
      amount: amt == null ? null : (amt as num).toDouble(),
      timestamp:
          DateTime.tryParse((map['timestamp'] ?? '') as String) ??
              DateTime.now(),
    );
  }
}
