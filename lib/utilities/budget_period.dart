class BudgetPeriod {
  const BudgetPeriod._();

  static String keyFor(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  static DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);
  }

  static DateTime nextMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 1);
  }

  static int daysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  static int daysElapsed(DateTime selectedMonth) {
    final now = DateTime.now();
    final monthStart = startOfMonth(selectedMonth);
    final days = daysInMonth(selectedMonth);

    if (monthStart.isAfter(DateTime(now.year, now.month, 1))) {
      return 0;
    }

    if (DateTime(selectedMonth.year, selectedMonth.month + 1, 0)
        .isBefore(DateTime(now.year, now.month, now.day))) {
      return days;
    }

    return (now.day - 1).clamp(0, days);
  }

  static int daysRemaining(DateTime selectedMonth) {
    final now = DateTime.now();
    final monthStart = startOfMonth(selectedMonth);
    final monthEnd = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    if (monthStart.isAfter(DateTime(now.year, now.month, 1))) {
      return monthEnd.day;
    }

    if (monthEnd.isBefore(DateTime(now.year, now.month, now.day))) {
      return 0;
    }

    return monthEnd.day - now.day + 1;
  }
}
