import 'package:coin_manager/utilities/budget_rules.dart';
import 'package:coin_manager/utilities/functions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats INR with Indian digit grouping', () {
    expect(
      UtilityFunction.addCommaWithSign(
        1234567.89,
        currencySymbol: '₹',
        currencyCode: 'INR',
      ),
      '₹12,34,567.89',
    );

    expect(
      UtilityFunction.formatMoney(
        12345678,
        symbol: '₹',
        showDecimals: false,
      ),
      '₹1,23,45,678',
    );
  });

  test('Indian budget rule recognizes India-specific categories', () {
    final allocation = calculateBudgetAllocation(
      totalBudget: 100000,
      rule: indianBudgetRule,
      categoryNames: const [
        'Rent',
        'Groceries',
        'EMI',
        'Fuel',
        'Shopping',
        'Subscriptions',
      ],
    );

    expect(allocation.values.fold<double>(0, (sum, amount) => sum + amount),
        closeTo(100000, 0.01));
    expect(allocation['Rent'], greaterThan(allocation['Shopping']!));
    expect(allocation['EMI'], greaterThan(allocation['Subscriptions']!));
  });
}
