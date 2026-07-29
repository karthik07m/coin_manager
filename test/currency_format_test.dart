import 'package:flutter_test/flutter_test.dart';
import 'package:coin_manager/utilities/functions.dart';

void main() {
  group('currency-aware formatting', () {
    test('USD: western grouping, 2 decimals, sign before symbol', () {
      UtilityFunction.activeCurrencyCode = 'USD';
      expect(
        UtilityFunction.formatMoney(1234567.89,
            symbol: '\$', currencyCode: 'USD', showDecimals: true),
        '\$1,234,567.89',
      );
      expect(
        UtilityFunction.formatMoney(-1234.56,
            symbol: '\$', currencyCode: 'USD', showDecimals: true),
        '-\$1,234.56',
      );
      expect(
        UtilityFunction.formatMoney(1234.56, symbol: '\$', currencyCode: 'USD'),
        '\$1,235',
      );
    });

    test('INR: lakh/crore grouping, resolved from symbol alone', () {
      UtilityFunction.activeCurrencyCode = 'INR';
      // Most call sites pass only the symbol.
      expect(
        UtilityFunction.formatMoney(1234567.89,
            symbol: '₹', showDecimals: true),
        '₹12,34,567.89',
      );
      expect(
        UtilityFunction.formatMoney(-100000, symbol: '₹', showDecimals: true),
        '-₹1,00,000.00',
      );
    });

    test('JPY: no minor units even when decimals requested', () {
      UtilityFunction.activeCurrencyCode = 'JPY';
      expect(
        UtilityFunction.formatMoney(1234.56, symbol: '¥', showDecimals: true),
        '¥1,235',
      );
    });

    test('CNY disambiguated from JPY by active code (shared ¥ symbol)', () {
      UtilityFunction.activeCurrencyCode = 'CNY';
      expect(
        UtilityFunction.formatMoney(1234.56, symbol: '¥', showDecimals: true),
        '¥1,234.56',
      );
    });

    test('addCommaWithSign follows the same currency rules', () {
      UtilityFunction.activeCurrencyCode = 'INR';
      expect(
        UtilityFunction.addCommaWithSign(1234567.89,
            currencySymbol: '₹', currencyCode: 'INR'),
        '₹12,34,567.89',
      );
      UtilityFunction.activeCurrencyCode = 'USD';
      expect(
        UtilityFunction.addCommaWithSign(-1234.5,
            currencySymbol: '\$', currencyCode: 'USD'),
        '-\$1,234.50',
      );
    });

    test('compact labels use lakh/crore for INR and k/M elsewhere', () {
      UtilityFunction.activeCurrencyCode = 'INR';
      expect(
        UtilityFunction.formatCompactMoney(150000, symbol: '₹'),
        contains('L'),
      );
      UtilityFunction.activeCurrencyCode = 'USD';
      expect(
        UtilityFunction.formatCompactMoney(150000, symbol: '\$'),
        '\$150k',
      );
      expect(
        UtilityFunction.formatCompactMoney(2500000, symbol: '\$'),
        '\$2.5M',
      );
    });
  });
}
