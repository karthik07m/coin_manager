import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/bill_reminder_scheduler.dart';
import '../utilities/budget_rules.dart';
import '../utilities/functions.dart';
import '../models/regional_preferences.dart';

class AccentColorOption {
  final String name;
  final Color color;

  const AccentColorOption({
    required this.name,
    required this.color,
  });
}

class SettingsProvider extends ChangeNotifier {
  /// The AI backend endpoint. Ships with the app rather than being asked of
  /// the user — it is infrastructure, not a preference.
  ///
  /// Overridable at build time without touching source, so staging and
  /// production builds can point at different functions:
  ///   flutter build apk --dart-define=AI_FUNCTION_URL=https://...
  ///
  /// Note this is not a secret: strings are readable in any shipped binary.
  /// The endpoint must be protected by the function's own auth, not by hiding
  /// the URL here.
  static const String defaultAiFunctionUrl = String.fromEnvironment(
    'AI_FUNCTION_URL',
    defaultValue:
        'https://vrpgaapkanixbqurxqwu.supabase.co/functions/v1/finance-ai',
  );
  static const int defaultAccentColorValue = 0xFF2ECC71;
  static const List<AccentColorOption> accentColorOptions = [
    AccentColorOption(name: 'Emerald', color: Color(0xFF2ECC71)),
    AccentColorOption(name: 'Teal', color: Color(0xFF14B8A6)),
    AccentColorOption(name: 'Cyan', color: Color(0xFF06B6D4)),
    AccentColorOption(name: 'Blue', color: Color(0xFF3B82F6)),
    AccentColorOption(name: 'Indigo', color: Color(0xFF6366F1)),
    AccentColorOption(name: 'Violet', color: Color(0xFF8B5CF6)),
    AccentColorOption(name: 'Fuchsia', color: Color(0xFFD946EF)),
    AccentColorOption(name: 'Rose', color: Color(0xFFE11D48)),
    AccentColorOption(name: 'Orange', color: Color(0xFFF97316)),
    AccentColorOption(name: 'Yellow', color: Color(0xFFEAB308)),
  ];

  ThemeMode _themeMode = ThemeMode.system;
  int _accentColorValue = defaultAccentColorValue;

  /// Material You: derive the palette from the device wallpaper instead of a
  /// fixed accent. Off by default so existing installs keep their colour.
  bool _useDynamicColor = false;
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
  bool _enableNotifications = true;
  bool _billRemindersEnabled = true;
  TimeOfDay _notificationTime =
      const TimeOfDay(hour: 19, minute: 0); // Default 7 PM
  bool _isAppLockEnabled = false;
  bool _aiAssistantEnabled = true;
  bool _showHomeBalanceCard = true;
  bool _showHomeQuickStats = true;
  bool _showHomeUpcomingPayments = true;
  bool _showHomeDebtSummary = true;
  bool _showHomeGoals = true;
  bool _showHomeBudgetChart = false;
  bool _showHomeRecentTransactions = true;
  RegionalPreferences _regionalPreferences = const RegionalPreferences();
  bool _settingsLoaded = false;
  late final Future<void> ready;

  RegionalPreferences get regionalPreferences => _regionalPreferences;
  bool get shouldSuggestIndiaSetup => _settingsLoaded &&
      _currencyCode == 'INR' && !_regionalPreferences.indiaSetupHandled;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => Color(_accentColorValue);

  bool get useDynamicColor => _useDynamicColor;
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
  bool get billRemindersEnabled => _billRemindersEnabled;
  String get lastAutoIncomeMonth => _lastAutoIncomeMonth;
  TimeOfDay get notificationTime => _notificationTime;
  bool get isAppLockEnabled => _isAppLockEnabled;
  bool get aiAssistantEnabled => _aiAssistantEnabled;
  String get aiFunctionUrl => defaultAiFunctionUrl;
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
    ready = _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // New installs follow the phone. A saved choice wins; builds before the
    // System/Light/Dark picker only stored 'isDark', and installs that never
    // touched the switch were on the old dark default, so keep them dark.
    final savedMode = prefs.getString('themeMode');
    final legacyIsDark = prefs.getBool('isDark');
    if (savedMode != null) {
      _themeMode = ThemeMode.values.firstWhere((m) => m.name == savedMode,
          orElse: () => ThemeMode.system);
    } else if (legacyIsDark != null) {
      _themeMode = legacyIsDark ? ThemeMode.dark : ThemeMode.light;
    } else if (prefs.getBool('isFirstLaunch') == false) {
      _themeMode = ThemeMode.dark;
    }
    _accentColorValue =
        prefs.getInt('accentColorValue') ?? defaultAccentColorValue;
    _useDynamicColor = prefs.getBool('useDynamicColor') ?? false;
    _currencyCode = prefs.getString('currencyCode') ?? 'INR';
    _currencySymbol = prefs.getString('currencySymbol') ?? '₹';
    _regionalPreferences =
        RegionalPreferences.decode(prefs.getString('regionalPreferences'));
    // Keep the formatter in sync so amounts use this currency's rules
    // (minor units, digit grouping) everywhere.
    UtilityFunction.activeCurrencyCode = _currencyCode;
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
    _enableNotifications = prefs.getBool('enableNotifications') ?? true;
    _billRemindersEnabled = prefs.getBool('billRemindersEnabled') ?? true;
    _isAppLockEnabled = prefs.getBool('isAppLockEnabled') ?? false;
    _aiAssistantEnabled = prefs.getBool('aiAssistantEnabled') ?? true;
    _showHomeBalanceCard = prefs.getBool('showHomeBalanceCard') ?? true;
    _showHomeQuickStats = prefs.getBool('showHomeQuickStats') ?? true;
    _showHomeUpcomingPayments =
        prefs.getBool('showHomeUpcomingPayments') ?? true;
    _showHomeDebtSummary = prefs.getBool('showHomeDebtSummary') ?? true;
    _showHomeGoals = prefs.getBool('showHomeGoals') ?? true;
    _showHomeBudgetChart = prefs.getBool('showHomeBudgetChart') ?? false;
    _showHomeRecentTransactions =
        prefs.getBool('showHomeRecentTransactions') ?? true;
    final notifHour = prefs.getInt('notificationHour') ?? 19;
    final notifMinute = prefs.getInt('notificationMinute') ?? 0;
    _notificationTime = TimeOfDay(hour: notifHour, minute: notifMinute);
    _settingsLoaded = true;
    notifyListeners();

    if (_enableNotifications) {
      await NotificationService().scheduleDailyReminder(
        hour: _notificationTime.hour,
        minute: _notificationTime.minute,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
    notifyListeners();
  }

  /// Turns wallpaper-derived theming on or off.
  Future<void> setUseDynamicColor(bool value) async {
    _useDynamicColor = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useDynamicColor', value);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    // Picking a colour by hand is an explicit choice to stop following the
    // wallpaper — otherwise the swatch would appear to do nothing.
    _useDynamicColor = false;
    _accentColorValue = color.toARGB32();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accentColorValue', _accentColorValue);
    await prefs.setBool('useDynamicColor', false);
    notifyListeners();
  }

  Future<void> setCurrency(String code, String symbol) async {
    await ready;
    _currencyCode = code;
    _currencySymbol = symbol;
    UtilityFunction.activeCurrencyCode = code;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currencyCode', code);
    await prefs.setString('currencySymbol', symbol);
    // Materialize a legacy/default rule too, so a relaunch cannot infer a
    // different rule from the newly selected currency.
    await prefs.setString('budgetRule', _budgetRule);
    notifyListeners();
  }

  Future<void> setRegionalPreferences(RegionalPreferences value) async {
    await ready;
    if (value.financialYearStartMonth < 1 || value.financialYearStartMonth > 12) {
      throw RangeError.range(value.financialYearStartMonth, 1, 12);
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString('regionalPreferences', value.encode());
    if (!saved) throw StateError('Could not save regional preferences');
    _regionalPreferences = value;
    notifyListeners();
  }

  Future<void> dismissIndiaSetup() async {
    await ready;
    await setRegionalPreferences(
        _regionalPreferences.copyWith(indiaSetupHandled: true));
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

  Future<void> setBillRemindersEnabled(bool enable) async {
    _billRemindersEnabled = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('billRemindersEnabled', enable);
    notifyListeners();

    if (enable) {
      await NotificationService().requestPermissions();
    }
    // reschedule() reads the flag we just persisted: it schedules when on,
    // and cancels everything when off.
    await BillReminderScheduler().reschedule();
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
