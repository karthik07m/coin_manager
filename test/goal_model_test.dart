import 'package:flutter_test/flutter_test.dart';
import 'package:coin_manager/models/goal.dart';

void main() {
  group('Goal.getProgressPercentage', () {
    test('zero target does not divide by zero', () {
      final g = Goal.createNew(id: '1', title: 'x', targetAmount: 0);
      expect(g.getProgressPercentage(), 0);
    });

    test('clamps to 100 when over target', () {
      final g = Goal.createNew(
        id: '1',
        title: 'x',
        targetAmount: 100,
        currentAmount: 150,
      );
      expect(g.getProgressPercentage(), 100);
    });
  });

  group('Goal.isAchieved', () {
    test('true at exactly target (>=)', () {
      final g = Goal.createNew(
        id: '1',
        title: 'x',
        targetAmount: 100,
        currentAmount: 100,
      );
      expect(g.isAchieved, isTrue);
    });

    test('false just below target', () {
      final g = Goal.createNew(
        id: '1',
        title: 'x',
        targetAmount: 100,
        currentAmount: 99.99,
      );
      expect(g.isAchieved, isFalse);
    });
  });

  group('Goal.getRemainingAmount', () {
    test('never negative', () {
      final g = Goal.createNew(
        id: '1',
        title: 'x',
        targetAmount: 100,
        currentAmount: 130,
      );
      expect(g.getRemainingAmount(), 0);
    });
  });

  group('Goal.getDaysUntilTarget (date-only)', () {
    test('target today at 00:01 returns 0', () {
      final now = DateTime.now();
      final g = Goal.createNew(
        id: '1',
        title: 'x',
        targetAmount: 100,
        targetDate: DateTime(now.year, now.month, now.day, 0, 1),
      );
      expect(g.getDaysUntilTarget(), 0);
    });

    test('null target returns null', () {
      final g = Goal.createNew(id: '1', title: 'x', targetAmount: 100);
      expect(g.getDaysUntilTarget(), isNull);
    });
  });

  group('Goal map round-trip', () {
    test('preserves fields', () {
      final g = Goal.createNew(
        id: '1',
        title: 'Vacation',
        targetAmount: 5000,
        currentAmount: 1200,
        targetDate: DateTime(2026, 12, 31),
        notes: 'Beach',
      );
      final restored = Goal.fromMap(g.toMap());
      expect(restored.title, 'Vacation');
      expect(restored.targetAmount, 5000);
      expect(restored.currentAmount, 1200);
      expect(restored.notes, 'Beach');
      expect(restored.targetDate, DateTime(2026, 12, 31));
    });
  });
}
