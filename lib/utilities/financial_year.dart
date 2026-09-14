/// A twelve-month reporting window. [startYear] is the year it starts in.
class FinancialYear {
  final int startYear;
  final int startMonth;

  FinancialYear(this.startYear, {this.startMonth = 1}) {
    if (startMonth < 1 || startMonth > 12) {
      throw RangeError.range(startMonth, 1, 12, 'startMonth');
    }
  }

  factory FinancialYear.containing(DateTime date, {int startMonth = 1}) =>
      FinancialYear(date.year - (date.month < startMonth ? 1 : 0),
          startMonth: startMonth);

  DateTime get start => DateTime(startYear, startMonth);
  DateTime get endExclusive => DateTime(startYear + 1, startMonth);
  DateTime get end =>
      DateTime(startYear + 1, startMonth, 0, 23, 59, 59, 999, 999);
  String get label =>
      startMonth == 1 ? '$startYear' : '$startYear–${startYear + 1}';

  DateTime monthAt(int index) {
    if (index < 0 || index > 11) {
      throw RangeError.range(index, 0, 11, 'index');
    }
    return DateTime(startYear, startMonth + index);
  }

  int indexOf(DateTime date) {
    final index = (date.year - startYear) * 12 + date.month - startMonth;
    if (index < 0 || index > 11) {
      throw ArgumentError.value(date, 'date', 'Outside this financial year');
    }
    return index;
  }
}
