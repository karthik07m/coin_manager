# PLAN: Bill & debt due-date reminders

**Rank: 4 of 5.** The app already knows every upcoming recurring bill and every
debt due date, and already ships a working notification stack
(`flutter_local_notifications` + timezone init + Android channel + permission
flows in `lib/services/notification_service.dart`). Connecting the two is the
single biggest "professional finance app" feature for the effort involved.

## Goal

Local notifications: "House Loan (\$2,000) due tomorrow" the day before each
upcoming recurring expense and each debt due date, with a Settings toggle,
rescheduled automatically whenever the underlying data changes.

## Exact files to touch

- `lib/services/notification_service.dart` — new channel + scheduling API
- `lib/providers/settings_provider.dart` — `billRemindersEnabled` setting
- `lib/screens/setting.dart` — toggle tile in the Notifications section
- `lib/screens/menu_scrn.dart` — reschedule after startup data load
- `lib/providers/debt_provider.dart` — reschedule hook after add/update/delete
- `lib/providers/transaction_provider.dart` — expose data only (no scheduling here)
- NEW `lib/services/bill_reminder_scheduler.dart` — the orchestration

## Step-by-step

1. `NotificationService` additions (`lib/services/notification_service.dart`):
   - In `init()`, create a second Android channel:
     id `'bill_reminder_channel'`, name `'Bill Reminders'`,
     description `'Upcoming bill and debt due dates'`, importance max.
   - Add:
     ```dart
     Future<void> scheduleOneTime({
       required int id,
       required String title,
       required String body,
       required DateTime when,
     }) async { ... }
     ```
     using `zonedSchedule` with
     `tz.TZDateTime.from(when, tz.local)`, the bill channel, and the SAME
     exact/inexact fallback pattern `scheduleDailyReminder` already uses
     (`canScheduleExactAlarms()` → `exactAllowWhileIdle` else
     `inexactAllowWhileIdle`). **Edge case:** `zonedSchedule` THROWS on a
     past datetime — guard `if (when.isBefore(DateTime.now())) return;`.
   - Add `Future<void> cancelIds(List<int> ids)` looping
     `flutterLocalNotificationsPlugin.cancel(id)`.
2. NEW `lib/services/bill_reminder_scheduler.dart`:
   ```dart
   class BillReminderScheduler {
     static const _prefsKey = 'scheduledBillReminderIds';
     // id space: bill reminders use 10000..19999 so they can never collide
     // with daily reminder (0) or the test notification (9999... use 20000+ if
     // 9999 < 19999 — CHECK: 9999 IS inside 0..19999, so use 20000..29999).
   ```
   **Edge case a weaker model would miss:** the existing code already uses
   notification id `0` (daily reminder) and `9999` (test notification). Choose
   the bill range **20000–29999** to avoid both.
   - `Future<void> reschedule()`:
     a. Read previously scheduled ids from SharedPreferences, `cancelIds` them,
        clear the list. (Cancel-then-reschedule beats diffing and prevents
        duplicates — `String.hashCode` is NOT stable across app upgrades, so do
        not derive ids from hashes; use sequential ids 20000, 20001, … and
        persist the list.)
     b. If `billRemindersEnabled` is false → stop after the cancel.
     c. Gather bills: `TransactionDBHelper().getAllUpcomingRecurringTransactions()`
        (already returns tomorrow → end of next month, expenses only), cap at
        the next 30 days.
     d. Gather debts: `DebtDBHelper().getDebts()` filtered to
        `status != DebtStatus.paid && dueDate != null` with dueDate within the
        next 30 days.
     e. For each item, schedule at **09:00 local time one day before** the due
        date; if that instant is already past (bill due today or tomorrow
        before 9am), schedule at `DateTime.now().add(const Duration(minutes: 2))`
        instead — never silently drop an imminent bill.
        Title: `'Upcoming: <title>'`; body:
        `'<formatted amount> due <Today/Tomorrow/MMM d>'` — reuse
        `UtilityFunction.formatMoney` with the symbol from SharedPreferences
        key `currencySymbol` (read it directly; the scheduler must not depend
        on a BuildContext).
     f. Persist the used id list.
   **Edge case:** debts may ALSO exist as recurring transactions (the loan flow
   creates both) — dedupe by skipping a debt whose `dueDate` and `amount` match
   a bill already scheduled that day (string key `'$day|$amount'` in a Set).
3. `SettingsProvider` (`lib/providers/settings_provider.dart`): add
   `_billRemindersEnabled` (default `false`), getter, `_loadSettings` read,
   and `setBillRemindersEnabled(bool)` persisting to key
   `'billRemindersEnabled'`. In the setter: when enabling, call
   `NotificationService().requestPermissions()` first, then
   `BillReminderScheduler().reschedule()`; when disabling, call `reschedule()`
   (which cancels everything because the flag is off). Follow the exact pattern
   of `toggleNotifications` two methods above it.
4. `setting.dart`: add a `_buildSettingTile` with a `Switch` directly under the
   'Daily Reminder' tile: title `'Bill Reminders'`, subtitle
   `'Notify the day before bills and debts are due'`, wired to
   `settings.billRemindersEnabled` / `setBillRemindersEnabled`.
5. Reschedule triggers:
   - `menu_scrn.dart` → at the END of `_loadAndCheckRecurring()` (after
     recurring generation and loads):
     `await BillReminderScheduler().reschedule();`
   - `debt_provider.dart` → fire-and-forget
     `BillReminderScheduler().reschedule();` (no await) at the end of the
     success paths of `addDebt`, `updateDebt`, `deleteDebt`, `recordPayment`.
     **Edge case:** DebtProvider must not import Flutter UI; the scheduler
     only touches services + SharedPreferences, so the import is safe.
   - Transaction add/update/delete of recurring items: call the scheduler from
     `TransactionProvider.addTransaction/updateTransaction/deleteTransaction`
     ONLY when `transaction.isRecurring` is true (avoids churn on every coffee).
6. `flutter analyze`; build debug APK; install.
7. Manual test script (works without waiting a day): temporarily create a
   recurring expense due tomorrow; toggle Bill Reminders on; the imminent-bill
   fallback (step 2e) fires a notification ~2 minutes later if 9am-yesterday
   logic puts it in the past — otherwise verify via
   `adb shell dumpsys notification --noredact | grep -A3 coinManager` that a
   scheduled alarm exists. Delete the test expense afterwards.

## Edge cases recap (the ones that bite)

- id collision with existing 0 / 9999 → use 20000+.
- `String.hashCode` instability → persist explicit id lists instead.
- `zonedSchedule` throws on past instants → guard + imminent fallback.
- Exact-alarm permission may be denied on Android 12+ → reuse existing
  `canScheduleExactAlarms()` fallback, never crash.
- Scheduler must be context-free (read currency from SharedPreferences).
- Loan-created debts duplicate their recurring transaction → dedupe by day+amount.

## Acceptance criteria

- [ ] Settings shows a working "Bill Reminders" toggle that persists across restart
- [ ] With the toggle ON and a recurring bill due within 2 days, a notification
      arrives (imminent fallback ≤ ~2 min for past-9am cases)
- [ ] Toggling OFF cancels: `dumpsys notification` shows no coinManager alarms
      in the 20000+ id range
- [ ] Creating/deleting a debt with a due date updates the scheduled set without
      duplicates (toggle off→on twice produces the same count)
- [ ] Daily reminder (id 0) still works untouched
- [ ] Analyzer clean, debug APK builds
