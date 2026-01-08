import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
