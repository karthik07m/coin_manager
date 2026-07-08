import 'package:flutter_test/flutter_test.dart';
import 'package:coin_manager/models/debt.dart';

void main() {
  group('Debt.getDaysUntilDue (date-only)', () {
    test('due today at 00:01 returns 0, not -1', () {
      final now = DateTime.now();
      final debt = Debt.createNew(
        id: '1',
        title: 'x',
        amount: 100,
        debtorName: 'A',
        isLiability: true,
        dueDate: DateTime(now.year, now.month, now.day, 0, 1),
      );
      expect(debt.getDaysUntilDue(), 0);
    });

    test('null dueDate returns null', () {
      final debt = Debt.createNew(
        id: '1',
        title: 'x',
        amount: 100,
        debtorName: 'A',
        isLiability: true,
      );
      expect(debt.getDaysUntilDue(), isNull);
    });

    test('tomorrow returns 1', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final debt = Debt.createNew(
        id: '1',
        title: 'x',
        amount: 100,
        debtorName: 'A',
        isLiability: true,
        dueDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 0),
      );
      expect(debt.getDaysUntilDue(), 1);
    });
  });

  group('Debt.getProgressPercentage', () {
    test('zero amount does not divide by zero', () {
      final debt = Debt.createNew(
        id: '1',
        title: 'x',
        amount: 0,
        debtorName: 'A',
        isLiability: true,
      );
      expect(debt.getProgressPercentage(), 0);
    });

    test('clamps to 100 when overpaid', () {
      final debt = Debt.createNew(
        id: '1',
        title: 'x',
        amount: 100,
        amountPaid: 150,
        debtorName: 'A',
        isLiability: true,
      );
      expect(debt.getProgressPercentage(), 100);
    });

    test('half paid is 50 percent', () {
      final debt = Debt.createNew(
        id: '1',
        title: 'x',
        amount: 200,
        amountPaid: 100,
        debtorName: 'A',
        isLiability: true,
      );
      expect(debt.getProgressPercentage(), 50);
    });
  });

  group('Debt.update status transitions', () {
    Debt base() => Debt.createNew(
          id: '1',
          title: 'x',
          amount: 100,
          debtorName: 'A',
          isLiability: true,
        );

    test('fully paid -> paid', () {
      final d = base()
        ..update(
          title: 'x',
          amount: 100,
          amountPaid: 100,
          debtorName: 'A',
          isLiability: true,
        );
      expect(d.status, DebtStatus.paid);
    });

    test('past due with partial payment -> overdue', () {
      final d = base()
        ..update(
          title: 'x',
          amount: 100,
          amountPaid: 40,
          debtorName: 'A',
          isLiability: true,
          dueDate: DateTime.now().subtract(const Duration(days: 3)),
        );
      expect(d.status, DebtStatus.overdue);
    });

    test('future due date with partial payment -> active', () {
      final d = base()
        ..update(
          title: 'x',
          amount: 100,
          amountPaid: 40,
          debtorName: 'A',
          isLiability: true,
          dueDate: DateTime.now().add(const Duration(days: 10)),
        );
      expect(d.status, DebtStatus.active);
    });
  });

  group('Debt map round-trip', () {
    test('preserves transactionId', () {
      final d = Debt.createNew(
        id: '1',
        title: 'Loan',
        amount: 500,
        debtorName: 'John',
        isLiability: false,
        transactionId: 'txn-123',
      );
      final restored = Debt.fromMap(d.toMap());
      expect(restored.transactionId, 'txn-123');
      expect(restored.debtorName, 'John');
      expect(restored.isLiability, isFalse);
    });

    test('null transactionId stays null', () {
      final d = Debt.createNew(
        id: '1',
        title: 'Loan',
        amount: 500,
        debtorName: 'John',
        isLiability: true,
      );
      final restored = Debt.fromMap(d.toMap());
      expect(restored.transactionId, isNull);
    });
  });
}
