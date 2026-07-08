import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../utilities/budget_rules.dart';

class AccentColorOption {
  final String name;
  final Color color;

  const AccentColorOption({
    required this.name,
    required this.color,
  });
}

class SettingsProvider extends ChangeNotifier {
  static const String defaultAiFunctionUrl =
      'https://vrpgaapkanixbqurxqwu.supabase.co/functions/v1/finance-ai';
  static const int defaultAccentColorValue = 0xFF2ECC71;
  static const List<AccentColorOption> accentColorOptions = [
    AccentColorOption(name: 'Emerald', color: Color(0xFF2ECC71)),
    AccentColorOption(name: 'Teal', color: Color(0xFF14B8A6)),
    AccentColorOption(name: 'Blue', color: Color(0xFF3B82F6)),
    AccentColorOption(name: 'Indigo', color: Color(0xFF6366F1)),
    AccentColorOption(name: 'Violet', color: Color(0xFF8B5CF6)),
    AccentColorOption(name: 'Rose', color: Color(0xFFE11D48)),
    AccentColorOption(name: 'Amber', color: Color(0xFFF59E0B)),
  ];

  ThemeMode _themeMode = ThemeMode.dark;
  int _accentColorValue = defaultAccentColorValue;
  String _currencyCode = 'INR';
  String _currencySymbol = '₹';
  bool _isFirstLaunch = true;
  double _defaultIncome = 0.0;
  double _monthlyIncome = 0.0;
  double _monthlyBudget = 0.0;
  String _budgetRule = indianBudgetRule.name;
  bool _recurIncome = false;
  bool _recurBudget = false;
  int _incomeDay = 1; // Day of month for recurring income (1-28)
  bool _use24HourFormat = false; // Default to 12-hour format
  String _lastAutoIncomeMonth =
      ''; // "YYYY-M" of the last month auto-income was added
  bool _enableNotifications = false;
  TimeOfDay _notificationTime =
      const TimeOfDay(hour: 20, minute: 0); // Default 8 PM
  bool _isAppLockEnabled = false;
  bool _aiAssistantEnabled = false;
  String _aiFunctionUrl = defaultAiFunctionUrl;
  bool _showHomeBalanceCard = true;
  bool _showHomeQuickStats = true;
  bool _showHomeUpcomingPayments = true;
  bool _showHomeDebtSummary = true;
  bool _showHomeGoals = true;
  bool _showHomeBudgetChart = true;
  bool _showHomeRecentTransactions = true;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => Color(_accentColorValue);
  String get accentColorName {
    return accentColorOptions
        .firstWhere(
          (option) => option.color.toARGB32() == _accentColorValue,
          orElse: () => accentColorOptions.first,
        )
        .name;
  }

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
  bool get isAppLockEnabled => _isAppLockEnabled;
  bool get aiAssistantEnabled => _aiAssistantEnabled;
  String get aiFunctionUrl =>
      _aiFunctionUrl.trim().isEmpty ? defaultAiFunctionUrl : _aiFunctionUrl;
  bool get showHomeBalanceCard => _showHomeBalanceCard;
  bool get showHomeQuickStats => _showHomeQuickStats;
  bool get showHomeUpcomingPayments => _showHomeUpcomingPayments;
  bool get showHomeDebtSummary => _showHomeDebtSummary;
  bool get showHomeGoals => _showHomeGoals;
  bool get showHomeBudgetChart => _showHomeBudgetChart;
  bool get showHomeRecentTransactions => _showHomeRecentTransactions;
  bool get hasVisibleHomeWidgets =>
      _showHomeBalanceCard ||
      _showHomeQuickStats ||
      _showHomeUpcomingPayments ||
      _showHomeDebtSummary ||
      _showHomeGoals ||
      _showHomeBudgetChart ||
      _showHomeRecentTransactions;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark');
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    }
    _accentColorValue =
        prefs.getInt('accentColorValue') ?? defaultAccentColorValue;
    _currencyCode = prefs.getString('currencyCode') ?? 'INR';
    _currencySymbol = prefs.getString('currencySymbol') ?? '₹';
    _isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    _defaultIncome = prefs.getDouble('defaultIncome') ?? 0.0;
    _monthlyIncome = prefs.getDouble('monthlyIncome') ?? 0.0;
    _monthlyBudget = prefs.getDouble('monthlyBudget') ?? 0.0;
    _budgetRule = prefs.getString('budgetRule') ??
        (_currencyCode == 'INR'
            ? indianBudgetRule.name
            : budgetRules.first.name);
    _recurIncome = prefs.getBool('recurIncome') ?? false;
    _recurBudget = prefs.getBool('recurBudget') ?? false;
    _incomeDay = prefs.getInt('incomeDay') ?? 1;
    _lastAutoIncomeMonth = prefs.getString('lastAutoIncomeMonth') ?? '';
    _use24HourFormat = prefs.getBool('use24HourFormat') ?? false;
    _enableNotifications = prefs.getBool('enableNotifications') ?? false;
    _isAppLockEnabled = prefs.getBool('isAppLockEnabled') ?? false;
    _aiAssistantEnabled = prefs.getBool('aiAssistantEnabled') ?? false;
    _aiFunctionUrl = prefs.getString('aiFunctionUrl') ?? defaultAiFunctionUrl;
    _showHomeBalanceCard = prefs.getBool('showHomeBalanceCard') ?? true;
    _showHomeQuickStats = prefs.getBool('showHomeQuickStats') ?? true;
    _showHomeUpcomingPayments =
        prefs.getBool('showHomeUpcomingPayments') ?? true;
    _showHomeDebtSummary = prefs.getBool('showHomeDebtSummary') ?? true;
    _showHomeGoals = prefs.getBool('showHomeGoals') ?? true;
    _showHomeBudgetChart = prefs.getBool('showHomeBudgetChart') ?? true;
    _showHomeRecentTransactions =
        prefs.getBool('showHomeRecentTransactions') ?? true;
    final notifHour = prefs.getInt('notificationHour') ?? 20;
    final notifMinute = prefs.getInt('notificationMinute') ?? 0;
    _notificationTime = TimeOfDay(hour: notifHour, minute: notifMinute);
    notifyListeners();

    if (_enableNotifications) {
      await NotificationService().scheduleDailyReminder(
        hour: _notificationTime.hour,
        minute: _notificationTime.minute,
      );
    }
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColorValue = color.toARGB32();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accentColorValue', _accentColorValue);
    notifyListeners();
  }

  Future<void> setCurrency(String code, String symbol) async {
    _currencyCode = code;
    _currencySymbol = symbol;
    if (code == 'INR' && _usesGenericBudgetRule) {
      _budgetRule = indianBudgetRule.name;
    } else if (code != 'INR' && _budgetRule == indianBudgetRule.name) {
      _budgetRule = budgetRules.first.name;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currencyCode', code);
    await prefs.setString('currencySymbol', symbol);
    await prefs.setString('budgetRule', _budgetRule);
    notifyListeners();
  }

  bool get _usesGenericBudgetRule {
    final normalized = _budgetRule.toLowerCase();
    return normalized.isEmpty ||
        normalized.contains('50/30/20') ||
        normalized.contains('50') ||
        normalized.contains('60/20/20') ||
        normalized.contains('60');
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

  Future<void> setAppLockEnabled(bool enabled) async {
    _isAppLockEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAppLockEnabled', enabled);
    notifyListeners();
  }

  Future<void> toggleAiAssistant(bool enabled) async {
    _aiAssistantEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('aiAssistantEnabled', enabled);
    notifyListeners();
  }

  Future<void> setAiFunctionUrl(String url) async {
    _aiFunctionUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aiFunctionUrl', _aiFunctionUrl);
    notifyListeners();
  }

  Future<void> setShowHomeBalanceCard(bool visible) async {
    _showHomeBalanceCard = visible;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showHomeBalanceCard', visible);
    notifyListeners();
  }

  Future<void> setShowHomeQuickStats(bool visible) async {
    _showHomeQuickStats = visible;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showHomeQuickStats', visible);
    notifyListeners();
  }

  Future<void> setShowHomeUpcomingPayments(bool visible) async {
    _showHomeUpcomingPayments = visible;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showHomeUpcomingPayments', visible);
    notifyListeners();
  }

  Future<void> setShowHomeDebtSummary(bool visible) async {
    _showHomeDebtSummary = visible;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showHomeDebtSummary', visible);
    notifyListeners();
  }

  Future<void> setShowHomeGoals(bool visible) async {
    _showHomeGoals = visible;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showHomeGoals', visible);
    notifyListeners();
  }

  Future<void> setShowHomeBudgetChart(bool visible) async {
    _showHomeBudgetChart = visible;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showHomeBudgetChart', visible);
    notifyListeners();
  }

  Future<void> setShowHomeRecentTransactions(bool visible) async {
    _showHomeRecentTransactions = visible;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showHomeRecentTransactions', visible);
    notifyListeners();
  }
}
