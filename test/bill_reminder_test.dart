import 'package:coin_manager/models/transaction.dart';
import 'package:coin_manager/services/bill_reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bill reminders are prompts to *pay* something. The upcoming-recurring
/// query they read from returns recurring income as well as expenses, so the
/// expense filter lives in the scheduler. Without it the user gets
/// "Upcoming: Monthly Income due tomorrow" — told to settle their own salary.
void main() {
  Transaction entry({
    required String title,
    required double amount,
    required bool isExpense,
    required DateTime date,
  }) {
    return Transaction.createNew(
      id: '$title-${date.toIso8601String()}',
      title: title,
      amount: amount,
      categoryId: 1,
      accountId: 1,
      date: date,
      isExpense: isExpense,
      isRecurring: true,
    );
  }

  final today = DateTime(2026, 8, 14);
  final windowEnd = today.add(const Duration(days: 30));

  group('billsNeedingReminder', () {
    test('drops recurring income', () {
      final result = BillReminderScheduler.billsNeedingReminder([
        entry(
          title: 'Monthly Income',
          amount: 6296.30,
          isExpense: false,
          date: DateTime(2026, 8, 15),
        ),
        entry(
          title: 'Car Loan',
          amount: 327.06,
          isExpense: true,
          date: DateTime(2026, 8, 15),
        ),
      ], windowEnd);

      expect(result.map((t) => t.title), ['Car Loan']);
    });

    test('keeps every expense inside the window', () {
      final result = BillReminderScheduler.billsNeedingReminder([
        entry(
          title: 'Netflix',
          amount: 21.64,
          isExpense: true,
          date: DateTime(2026, 8, 20),
        ),
        entry(
          title: 'Adobe',
          amount: 20,
          isExpense: true,
          date: DateTime(2026, 8, 25),
        ),
      ], windowEnd);

      expect(result.length, 2);
    });

    test('drops expenses beyond the reminder window', () {
      final result = BillReminderScheduler.billsNeedingReminder([
        entry(
          title: 'Far Future Bill',
          amount: 99,
          isExpense: true,
          date: windowEnd.add(const Duration(days: 1)),
        ),
      ], windowEnd);

      expect(result, isEmpty);
    });

    test('a due date exactly on the window edge is still reminded', () {
      final result = BillReminderScheduler.billsNeedingReminder([
        entry(
          title: 'Edge Bill',
          amount: 10,
          isExpense: true,
          date: windowEnd,
        ),
      ], windowEnd);

      expect(result.map((t) => t.title), ['Edge Bill']);
    });

    test('an all-income list schedules nothing at all', () {
      final result = BillReminderScheduler.billsNeedingReminder([
        entry(
          title: 'Salary',
          amount: 500,
          isExpense: false,
          date: DateTime(2026, 8, 15),
        ),
        entry(
          title: 'Freelance',
          amount: 1781.13,
          isExpense: false,
          date: DateTime(2026, 8, 16),
        ),
      ], windowEnd);

      expect(result, isEmpty);
    });
  });
}
