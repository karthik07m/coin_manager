import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  String _currencyCode = 'USD';
  String _currencySymbol = '\$';
  bool _isFirstLaunch = true;
  double _defaultIncome = 0.0;
  double _monthlyIncome = 0.0;
  double _monthlyBudget = 0.0;
  String _budgetRule = '50/30/20';
  bool _recurIncome = false;
  bool _recurBudget = false;
  int _incomeDay = 1; // Day of month for recurring income (1-28)
  bool _use24HourFormat = false; // Default to 12-hour format
  String _lastAutoIncomeMonth = ''; // "YYYY-M" of the last month auto-income was added
  bool _enableNotifications = false;
  TimeOfDay _notificationTime =
      const TimeOfDay(hour: 20, minute: 0); // Default 8 PM

  ThemeMode get themeMode => _themeMode;
  String get currencyCode => _currencyCode;
  String get currencySymbol => _currencySymbol;
  bool get isFirstLaunch => _isFirstLaunch;
  double get defaultIncome => _defaultIncome; // Actually means defaultBudget
  double get monthlyIncome => _monthlyIncome;
  double get monthlyBudget => _monthlyBudget;
  String get budgetRule => _budgetRule;
  bool get recurIncome => _recurIncome;
  bool get recurBudget => _recurBudget;
  int get incomeDay => _incomeDay;
  bool get use24HourFormat => _use24HourFormat;
  bool get enableNotifications => _enableNotifications;
  String get lastAutoIncomeMonth => _lastAutoIncomeMonth;
  TimeOfDay get notificationTime => _notificationTime;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark');
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    }
    _currencyCode = prefs.getString('currencyCode') ?? 'USD';
    _currencySymbol = prefs.getString('currencySymbol') ?? '\$';
    _isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    _defaultIncome = prefs.getDouble('defaultIncome') ?? 0.0;
    _monthlyIncome = prefs.getDouble('monthlyIncome') ?? 0.0;
    _monthlyBudget = prefs.getDouble('monthlyBudget') ?? 0.0;
    _budgetRule = prefs.getString('budgetRule') ?? '50/30/20';
    _recurIncome = prefs.getBool('recurIncome') ?? false;
    _recurBudget = prefs.getBool('recurBudget') ?? false;
    _incomeDay = prefs.getInt('incomeDay') ?? 1;
    _lastAutoIncomeMonth = prefs.getString('lastAutoIncomeMonth') ?? '';
    _use24HourFormat = prefs.getBool('use24HourFormat') ?? false;
    _enableNotifications = prefs.getBool('enableNotifications') ?? false;
    final notifHour = prefs.getInt('notificationHour') ?? 20;
    final notifMinute = prefs.getInt('notificationMinute') ?? 0;
    _notificationTime = TimeOfDay(hour: notifHour, minute: notifMinute);
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
    notifyListeners();
  }

  Future<void> setCurrency(String code, String symbol) async {
    _currencyCode = code;
    _currencySymbol = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currencyCode', code);
    await prefs.setString('currencySymbol', symbol);
    await prefs.setString('currencySymbol', symbol);
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required double income,
    required double budget,
    required String budgetRule,
    required bool recurIncome,
    required bool recurBudget,
    int incomeDay = 1,
  }) async {
    _isFirstLaunch = false;
    _monthlyIncome = income;
    _monthlyBudget = budget;
    _budgetRule = budgetRule;
    _defaultIncome = budget; // This is actually the recurring budget amount
    _recurIncome = recurIncome;
    _recurBudget = recurBudget;
    _incomeDay = incomeDay;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    await prefs.setDouble('monthlyIncome', income);
    await prefs.setDouble('monthlyBudget', budget);
    await prefs.setString('budgetRule', budgetRule);
    await prefs.setDouble('defaultIncome', budget);
    await prefs.setBool('recurIncome', recurIncome);
    await prefs.setBool('recurBudget', recurBudget);
    await prefs.setInt('incomeDay', incomeDay);
    notifyListeners();
  }

  /// Marks that auto monthly income has been added for a given month.
  /// Call this after successfully inserting the auto-income transaction so
  /// we never re-add it even if the user deletes it later.
  Future<void> markAutoIncomeAdded(int year, int month) async {
    _lastAutoIncomeMonth = '$year-$month';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastAutoIncomeMonth', _lastAutoIncomeMonth);
    notifyListeners();
  }

  Future<void> toggleTimeFormat(bool use24Hour) async {
    _use24HourFormat = use24Hour;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use24HourFormat', use24Hour);
    notifyListeners();
  }

  Future<void> toggleNotifications(bool enable) async {
    _enableNotifications = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableNotifications', enable);

    if (enable) {
      await NotificationService().requestPermissions();
      await NotificationService().scheduleDailyReminder(
        hour: _notificationTime.hour,
        minute: _notificationTime.minute,
      );

      // Check if exact alarms are permitted and log
      final canScheduleExact =
          await NotificationService().canScheduleExactAlarms();
      debugPrint('Daily reminder enabled. Exact alarms: $canScheduleExact');

      if (!canScheduleExact) {
        debugPrint(
            '⚠️ Exact alarm permission not granted. Notifications may be delayed by up to 15 minutes.');
      }
    } else {
      await NotificationService().cancelDailyReminder();
    }
    notifyListeners();
  }

  Future<void> setNotificationTime(TimeOfDay time) async {
    _notificationTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notificationHour', time.hour);
    await prefs.setInt('notificationMinute', time.minute);

    if (_enableNotifications) {
      await NotificationService().scheduleDailyReminder(
        hour: time.hour,
        minute: time.minute,
      );
    }
    notifyListeners();
  }
}
