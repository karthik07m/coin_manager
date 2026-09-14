import 'package:coin_manager/models/regional_preferences.dart';
import 'package:coin_manager/providers/settings_provider.dart';
import 'package:coin_manager/utilities/budget_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsProvider> load() async {
    final settings = SettingsProvider();
    await settings.ready;
    addTearDown(settings.dispose);
    return settings;
  }

  setUp(() => SharedPreferences.setMockInitialValues({
        'enableNotifications': false,
        'currencyCode': 'INR',
        'currencySymbol': '₹',
        'budgetRule': '60/20/20 Rule',
      }));

  test('existing INR installs are prompted without changing their preferences',
      () async {
    final settings = await load();
    expect(settings.shouldSuggestIndiaSetup, isTrue);
    expect(settings.regionalPreferences.indiaTemplates, isFalse);
    expect(settings.regionalPreferences.financialYearStartMonth, 1);
    expect(settings.budgetRule, '60/20/20 Rule');
  });

  test('dismissal persists across relaunch and currency round trips', () async {
    final settings = await load();
    await settings.dismissIndiaSetup();
    await settings.setCurrency('USD', r'$');
    await settings.setCurrency('INR', '₹');
    expect(settings.shouldSuggestIndiaSetup, isFalse);
    final restored = await load();
    expect(restored.shouldSuggestIndiaSetup, isFalse);
    expect(restored.regionalPreferences.indiaTemplates, isFalse);
    expect(restored.regionalPreferences.financialYearStartMonth, 1);
  });

  test('regional choices and budget rule survive every offered currency',
      () async {
    final settings = await load();
    await settings.setRegionalPreferences(const RegionalPreferences(
        indiaTemplates: true,
        financialYearStartMonth: 4,
        indiaSetupHandled: true));
    for (final currency in {
      'USD': r'$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'INR': '₹'
    }.entries) {
      await settings.setCurrency(currency.key, currency.value);
      expect(settings.regionalPreferences.indiaTemplates, isTrue);
      expect(settings.regionalPreferences.financialYearStartMonth, 4);
      expect(settings.budgetRule, '60/20/20 Rule');
    }
    final restored = await load();
    expect(restored.regionalPreferences.financialYearStartMonth, 4);
    expect(restored.regionalPreferences.indiaTemplates, isTrue);
  });

  test('switching away from INR preserves an explicitly chosen India rule',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('budgetRule', indianBudgetRule.name);
    final settings = await load();
    await settings.setCurrency('USD', r'$');
    expect(settings.budgetRule, indianBudgetRule.name);
    expect((await load()).budgetRule, indianBudgetRule.name);
  });

  test('USD users can independently opt into India templates and a July year',
      () async {
    final settings = await load();
    await settings.setCurrency('USD', r'$');
    expect(settings.shouldSuggestIndiaSetup, isFalse);
    await settings.setRegionalPreferences(const RegionalPreferences(
        indiaTemplates: true,
        financialYearStartMonth: 7,
        indiaSetupHandled: true));
    final restored = await load();
    expect(restored.currencyCode, 'USD');
    expect(restored.regionalPreferences.indiaTemplates, isTrue);
    expect(restored.regionalPreferences.financialYearStartMonth, 7);
  });

  test('corrupt or older preference data falls back to valid values', () {
    for (final value in [
      null,
      'bad JSON',
      '[]',
      'null',
      '{"financialYearStartMonth":13}',
      '{"financialYearStartMonth":"4"}'
    ]) {
      expect(RegionalPreferences.decode(value).financialYearStartMonth, 1);
    }
    final partial = RegionalPreferences.decode('{"indiaTemplates":true}');
    expect(partial.indiaTemplates, isTrue);
    expect(partial.indiaSetupHandled, isFalse);
  });

  test('an unstored legacy budget rule survives a currency change and relaunch',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('budgetRule');
    final settings = await load();
    final originalRule = settings.budgetRule;
    await settings.setCurrency('USD', r'$');
    expect((await load()).budgetRule, originalRule);
  });
}
