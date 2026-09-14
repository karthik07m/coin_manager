import 'package:coin_manager/utilities/budget_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sum of what the editor would actually store: every field is written to two
/// decimals, so the check has to be done on the rounded values.
double sumAsEntered(Map<String, double> allocation) {
  return allocation.values.fold<double>(
    0,
    (sum, value) => sum + double.parse(value.toStringAsFixed(2)),
  );
}

void main() {
  group('roundAllocationToTotal', () {
    test('an even split of an indivisible total lands exactly on the total',
        () {
      // 50,000 / 7 = 7142.857…; rounding each share to cents overshoots by
      // 2 paise, which used to trip "categories exceed your budget".
      final categories = List.generate(7, (i) => 'Category $i');
      final raw = {for (final name in categories) name: 50000 / 7};

      final allocation = roundAllocationToTotal(raw, 50000);

      expect(sumAsEntered(allocation), closeTo(50000, 0.001));
      expect(allocation.length, 7);
    });

    test('rule-based allocation never exceeds the budget it came from', () {
      final categoryNames = [
        'Food',
        'Rent',
        'Transport',
        'Shopping',
        'Entertainment',
        'Investment',
      ];

      for (final total in [10000.0, 33333.0, 87654.32, 1000000.0]) {
        for (final rule in budgetRules) {
          final allocation = roundAllocationToTotal(
            calculateBudgetAllocation(
              totalBudget: total,
              rule: rule,
              categoryNames: categoryNames,
            ),
            total,
          );

          expect(
            sumAsEntered(allocation),
            closeTo(total, 0.001),
            reason: 'rule ${rule.name} at total $total',
          );
        }
      }
    });

    test('keeps a single category whole', () {
      final allocation = roundAllocationToTotal({'Food': 1234.567}, 1234.57);
      expect(allocation['Food'], closeTo(1234.57, 0.001));
    });

    test('never pushes a category negative when correcting the remainder', () {
      // A residual bigger than the largest share can't drag it below zero.
      final allocation = roundAllocationToTotal({'Food': 10.0}, 0);
      expect(allocation['Food'], greaterThanOrEqualTo(0));
    });

    test('an empty split stays empty', () {
      expect(roundAllocationToTotal({}, 5000), isEmpty);
    });
  });
}
