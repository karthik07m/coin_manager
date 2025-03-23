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

  static List<Map<String, String>> getCategories(isExpense) {
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

  static String addComma(double value) {
    String amount = value.toStringAsFixed(2);
    // currency = CurrencyProvider.currentCurrency;

    String finalAmount = amount.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},");
    return " $currency $finalAmount";
  }

  static String addCommaWithSign(double value) {
    String amount = value.toStringAsFixed(2);

    currency = "\$";
    String finalAmount = amount.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},");
    return "$currency$finalAmount";
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
