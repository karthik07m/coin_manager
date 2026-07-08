import 'package:intl/intl.dart';

class UtilityFunction {
  static String currency = "₹";
  static String formateDate(DateTime date) {
    return DateFormat.yMMMd().format(date);
  }

  static String getScreenTitle(int screenId) {
    switch (screenId) {
      case 0:
        return "Home";
      case 1:
        return "Month Transaction";
      case 2:
        return "Screen";
      case 3:
        return "Settings";
      default:
        return "Unknown Screen"; // Return a default message for any unrecognized screen ID
    }
  }

  static String getImageString(int category) {
    switch (category) {
      case 1:
        return 'assets/categories/food.png';
      case 2:
        return 'assets/categories/groceries.png';
      case 3:
        return 'assets/categories/shopping.png';
      case 4:
        return 'assets/categories/transport.png';
      case 5:
        return 'assets/categories/entertainment.png';
      case 6:
        return 'assets/categories/salary.png';
      case 7:
        return 'assets/categories/bonus.png';
      case 8:
        return 'assets/categories/stocks.png';
      case 9:
        return 'assets/categories/travel.png';
      case 10:
        return 'assets/categories/bill.png';
      default:
        return 'assets/categories/other.png';
    }
  }

  static List<Map<String, String>> getCategories(bool isExpense) {
    final List<Map<String, String>> categories = isExpense
        ? [
            {'name': 'Food', 'icon': 'assets/categories/food.png'},
            {'name': 'Groceries', 'icon': 'assets/categories/groceries.png'},
            {'name': 'Shopping', 'icon': 'assets/categories/shopping.png'},
            {'name': 'Transit', 'icon': 'assets/categories/transport.png'},
            {
              'name': 'Entertainment',
              'icon': 'assets/categories/entertainment.png'
            },
            {'name': 'Utilities', 'icon': 'assets/categories/bill.png'},
            {'name': 'Travel', 'icon': 'assets/categories/travel.png'},
            {'name': 'Miscellaneous', 'icon': 'assets/categories/other.png'},
          ]
        : [
            {'name': 'Salary', 'icon': 'assets/categories/salary.png'},
            {'name': 'Stocks', 'icon': 'assets/categories/stocks.png'},
            {'name': 'Bonus', 'icon': 'assets/categories/bonus.png'},
            {'name': 'Miscellaneous', 'icon': 'assets/categories/other.png'},
          ];
    return categories;
  }

  // Utility method to check if two dates are the same day
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Format time based on user preference (12-hour or 24-hour)
  static String formatTime(DateTime dateTime, {bool use24Hour = false}) {
    if (use24Hour) {
      // 24-hour format: 14:30
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else {
      // 12-hour format: 2:30 PM
      int hour = dateTime.hour;
      final period = hour >= 12 ? 'PM' : 'AM';

      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour -= 12;
      }

      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period';
    }
  }

  static String addComma(double value) {
    String amount = value.toStringAsFixed(2);
    // currency = CurrencyProvider.currentCurrency;

    String finalAmount = amount.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},");
    return " $currency $finalAmount";
  }

  static bool isIndianCurrency({String? symbol, String? code}) {
    return code == 'INR' || symbol == '₹';
  }

  /// Format number with Indian numbering system (thousands, lakhs, crores).
  /// Example: 1234567.89 => 12,34,567.89
  static String formatIndianNumber(
    double value, {
    bool showDecimals = true,
  }) {
    final isNegative = value < 0;
    final normalized = value.abs();
    final parts = normalized.toStringAsFixed(showDecimals ? 2 : 0).split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '';

    if (intPart.length <= 3) {
      final amount = showDecimals ? '$intPart.$decPart' : intPart;
      return isNegative ? '-$amount' : amount;
    }

    final lastThree = intPart.substring(intPart.length - 3);
    var leading = intPart.substring(0, intPart.length - 3);
    final groups = <String>[];

    while (leading.length > 2) {
      groups.insert(0, leading.substring(leading.length - 2));
      leading = leading.substring(0, leading.length - 2);
    }

    if (leading.isNotEmpty) {
      groups.insert(0, leading);
    }

    final formatted = '${groups.join(',')},$lastThree';
    final amount = showDecimals ? '$formatted.$decPart' : formatted;
    return isNegative ? '-$amount' : amount;
  }

  static String addCommaWithSign(double value,
      {String currencySymbol = '\$', String currencyCode = 'USD'}) {
    String formattedAmount;

    if (isIndianCurrency(symbol: currencySymbol, code: currencyCode)) {
      formattedAmount = formatIndianNumber(value);
    } else {
      String amount = value.toStringAsFixed(2);
      formattedAmount = amount.replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},");
    }

    return "$currencySymbol$formattedAmount";
  }

  /// Format money with commas and optional decimals
  /// Example: 1234.56 => "$1,234" or "$1,234.56"
  static String formatMoney(
    double value, {
    bool showDecimals = false,
    String symbol = '\$',
    String currencyCode = 'USD',
  }) {
    if (isIndianCurrency(symbol: symbol, code: currencyCode)) {
      return '$symbol${formatIndianNumber(
        value,
        showDecimals: showDecimals,
      )}';
    }

    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: showDecimals ? 2 : 0,
    );
    return formatter.format(value);
  }

  static String formatIndianCompact(double value,
      {String currencySymbol = '₹', bool showDecimals = false}) {
    final absoluteValue = value.abs();
    final sign = value < 0 ? '-' : '';

    if (absoluteValue >= 10000000) {
      final amount = absoluteValue / 10000000;
      return '$sign$currencySymbol${amount.toStringAsFixed(amount >= 10 || !showDecimals ? 1 : 2)}Cr';
    }

    if (absoluteValue >= 100000) {
      final amount = absoluteValue / 100000;
      return '$sign$currencySymbol${amount.toStringAsFixed(amount >= 10 || !showDecimals ? 1 : 2)}L';
    }

    return '$sign${formatMoney(
      absoluteValue,
      symbol: currencySymbol,
      currencyCode: 'INR',
      showDecimals: showDecimals,
    )}';
  }

  static String formatDate(DateTime date) {
    if (isSameDay(date, DateTime.now())) {
      return 'Today';
    } else {
      return DateFormat.yMMMEd().format(date);
    }
  }

  static String getCategoryName(
      int categoryId, List<Map<String, dynamic>> categories) {
    final category = categories.firstWhere(
      (cat) => cat['id'] == categoryId,
      orElse: () => {'name': 'Unknown'}, // Default value if not found
    );
    return category['name'];
  }

  static bool isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
