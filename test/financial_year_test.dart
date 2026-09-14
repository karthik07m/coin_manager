import 'package:coin_manager/utilities/financial_year.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('March belongs to the prior April-start year', () {
    final period =
        FinancialYear.containing(DateTime(2026, 3, 31), startMonth: 4);
    expect(period.start, DateTime(2025, 4));
    expect(period.endExclusive, DateTime(2026, 4));
    expect(period.indexOf(DateTime(2026, 3)), 11);
    expect(period.monthAt(9), DateTime(2026, 1));
    expect(period.label, '2025–2026');
  });

  test('April starts a new year and includes the final microsecond of March',
      () {
    final period = FinancialYear.containing(DateTime(2026, 4), startMonth: 4);
    expect(period.start, DateTime(2026, 4));
    expect(period.end, DateTime(2027, 3, 31, 23, 59, 59, 999, 999));
  });

  test('calendar-year behavior remains January through December', () {
    final period = FinancialYear.containing(DateTime(2026, 12, 31));
    expect(period.start, DateTime(2026, 1));
    expect(period.monthAt(11), DateTime(2026, 12));
    expect(period.label, '2026');
  });

  test('all start months map all twelve months and leap days correctly', () {
    for (var month = 1; month <= 12; month++) {
      final period =
          FinancialYear.containing(DateTime(2024, 2, 29), startMonth: month);
      for (var index = 0; index < 12; index++) {
        expect(period.indexOf(period.monthAt(index)), index);
        expect(
            FinancialYear.containing(period.monthAt(index), startMonth: month)
                .start,
            period.start);
      }
      expect(DateTime(2024, 2, 29).isBefore(period.start), isFalse);
      expect(DateTime(2024, 2, 29).isBefore(period.endExclusive), isTrue);
    }
  });

  test('invalid months and out-of-period navigation fail explicitly', () {
    expect(() => FinancialYear(2026, startMonth: 13), throwsRangeError);
    final period = FinancialYear(2026, startMonth: 4);
    expect(() => period.monthAt(12), throwsRangeError);
    expect(() => period.indexOf(DateTime(2026, 3)), throwsArgumentError);
  });
}
