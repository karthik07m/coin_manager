import 'package:flutter_test/flutter_test.dart';
import 'package:coin_manager/utilities/functions.dart';

void main() {
  group('formatIndianNumber', () {
    test('groups lakhs and crores', () {
      expect(UtilityFunction.formatIndianNumber(1234567.89), '12,34,567.89');
    });
    test('no decimals when showDecimals is false (rounds via toStringAsFixed)', () {
      // .89 rounds up — formatIndianNumber uses toStringAsFixed(0), not truncation.
      expect(
        UtilityFunction.formatIndianNumber(1234567.89, showDecimals: false),
        '12,34,568',
      );
      // A clean integer confirms the grouping itself.
      expect(
        UtilityFunction.formatIndianNumber(1234567.0, showDecimals: false),
        '12,34,567',
      );
    });
    test('negatives keep a leading minus', () {
      expect(UtilityFunction.formatIndianNumber(-1234567.0), '-12,34,567.00');
    });
    test('small numbers are not grouped', () {
      expect(UtilityFunction.formatIndianNumber(999.5), '999.50');
    });
  });

  group('formatIndianCompact', () {
    test('crore', () {
      expect(UtilityFunction.formatIndianCompact(12500000), '₹1.3Cr');
    });
    test('lakh', () {
      expect(UtilityFunction.formatIndianCompact(250000), '₹2.5L');
    });
    test('below a lakh falls through to plain formatting', () {
      // No Cr/L suffix under 1,00,000.
      final out = UtilityFunction.formatIndianCompact(5000);
      expect(out.contains('Cr'), isFalse);
      expect(out.contains('L'), isFalse);
    });
  });

  group('addCommaWithSign', () {
    test('INR uses Indian grouping at lakh scale', () {
      expect(
        UtilityFunction.addCommaWithSign(1234567.0,
            currencySymbol: '₹', currencyCode: 'INR'),
        '₹12,34,567.00',
      );
    });
    test('USD uses western grouping', () {
      expect(
        UtilityFunction.addCommaWithSign(1234.5,
            currencySymbol: '\$', currencyCode: 'USD'),
        '\$1,234.50',
      );
    });
    test('symbol-only detection routes ₹ to Indian grouping', () {
      // isIndianCurrency matches on symbol OR code.
      expect(
        UtilityFunction.addCommaWithSign(1234567.0, currencySymbol: '₹'),
        '₹12,34,567.00',
      );
    });
  });

  group('formatMoney', () {
    test('USD hides decimals by default and rounds', () {
      // NumberFormat rounds 1234.56 -> 1,235 when decimalDigits is 0.
      expect(
        UtilityFunction.formatMoney(1234.56, symbol: '\$', currencyCode: 'USD'),
        '\$1,235',
      );
    });
    test('USD with decimals preserves cents', () {
      expect(
        UtilityFunction.formatMoney(1234.56,
            symbol: '\$', currencyCode: 'USD', showDecimals: true),
        '\$1,234.56',
      );
    });
  });

  group('isSameDay', () {
    test('same calendar day regardless of time', () {
      expect(
        UtilityFunction.isSameDay(
            DateTime(2026, 7, 6, 0, 1), DateTime(2026, 7, 6, 23, 59)),
        isTrue,
      );
    });
    test('different days', () {
      expect(
        UtilityFunction.isSameDay(DateTime(2026, 7, 6), DateTime(2026, 7, 7)),
        isFalse,
      );
    });
  });
}
