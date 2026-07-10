import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/debt_db_helper.dart';
import '../db/transaction_db_helper.dart';
import '../models/debt.dart';
import '../utilities/functions.dart';
import 'notification_service.dart';

/// Schedules "due tomorrow" notifications for upcoming recurring bills and
/// unpaid debts. Context-free: reads currency and the enabled flag straight
/// from SharedPreferences so it can run from providers or app startup.
///
/// Notification id space: 20000–29999, chosen to never collide with the
/// daily reminder (id 0) or the test notification (id 9999).
class BillReminderScheduler {
  static const _prefsScheduledKey = 'scheduledBillReminderIds';
  static const _prefsEnabledKey = 'billRemindersEnabled';
  static const _idBase = 20000;
  static const _windowDays = 30;

  Future<void> reschedule() async {
    final prefs = await SharedPreferences.getInstance();

    // Always cancel the previously-scheduled set first (cancel-then-reschedule
    // avoids duplicates; ids are persisted, not derived from unstable hashes).
    final previous = prefs
            .getStringList(_prefsScheduledKey)
            ?.map(int.tryParse)
            .whereType<int>()
            .toList() ??
        <int>[];
    await NotificationService().cancelIds(previous);
    await prefs.remove(_prefsScheduledKey);

    final enabled = prefs.getBool(_prefsEnabledKey) ?? false;
    if (!enabled) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final windowEnd = today.add(const Duration(days: _windowDays));
    final currency = prefs.getString('currencySymbol') ?? '₹';

    // Collect (dueDate, title, amount) items to remind about.
    final items = <_ReminderItem>[];

    // Recurring bills (expenses) already scoped tomorrow..end-of-next-month.
    try {
      final bills =
          await TransactionDBHelper().getAllUpcomingRecurringTransactions();
      for (final t in bills) {
        final due = DateTime(t.date.year, t.date.month, t.date.day);
        if (due.isAfter(windowEnd)) continue;
        items.add(_ReminderItem(due, t.title, t.amount));
      }
    } catch (e) {
      debugPrint('BillReminder: failed to load bills: $e');
    }

    // Unpaid debts with a due date in the window.
    try {
      final debts = await DebtDBHelper().getDebts();
      for (final d in debts) {
        if (d.status == DebtStatus.paid || d.dueDate == null) continue;
        final due = DateTime(d.dueDate!.year, d.dueDate!.month, d.dueDate!.day);
        if (due.isBefore(today) || due.isAfter(windowEnd)) continue;
        items.add(_ReminderItem(due, d.title, d.getRemainingAmount()));
      }
    } catch (e) {
      debugPrint('BillReminder: failed to load debts: $e');
    }

    // Dedup: a loan-created debt duplicates its recurring transaction. Key on
    // day + amount so we don't remind twice for the same obligation.
    final seen = <String>{};
    final scheduledIds = <int>[];
    int idCounter = _idBase;

    for (final item in items) {
      final key = '${item.due.toIso8601String()}|${item.amount}';
      if (!seen.add(key)) continue;

      // Fire at 09:00 the day before. If that instant is already past
      // (due today, or tomorrow before 9am), fire ~2 minutes from now so an
      // imminent bill is never silently dropped.
      final dayBefore9am = DateTime(
        item.due.year,
        item.due.month,
        item.due.day - 1,
        9,
      );
      final when = dayBefore9am.isBefore(now)
          ? now.add(const Duration(minutes: 2))
          : dayBefore9am;

      final id = idCounter++;
      await NotificationService().scheduleOneTime(
        id: id,
        title: 'Upcoming: ${item.title}',
        body:
            '${UtilityFunction.formatMoney(item.amount, symbol: currency)} due ${_dueLabel(item.due, today)}',
        when: when,
      );
      scheduledIds.add(id);
    }

    await prefs.setStringList(
      _prefsScheduledKey,
      scheduledIds.map((e) => e.toString()).toList(),
    );
  }

  String _dueLabel(DateTime due, DateTime today) {
    final diff = due.difference(today).inDays;
    if (diff <= 0) return 'today';
    if (diff == 1) return 'tomorrow';
    return DateFormat('MMM d').format(due);
  }
}

class _ReminderItem {
  final DateTime due;
  final String title;
  final double amount;
  _ReminderItem(this.due, this.title, this.amount);
}
