import 'package:coin_manager/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme chosen at startup for a given set of saved preferences.
Future<ThemeMode> themeFor(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(
      {'enableNotifications': false, ...saved});
  final settings = SettingsProvider();
  await settings.ready;
  return settings.themeMode;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a brand-new install follows the phone', () async {
    expect(await themeFor({}), ThemeMode.system);
  });

  test('an existing install that never picked a theme stays dark', () async {
    expect(await themeFor({'isFirstLaunch': false}), ThemeMode.dark);
  });

  test('the old dark-mode switch set to off stays light', () async {
    expect(await themeFor({'isFirstLaunch': false, 'isDark': false}),
        ThemeMode.light);
  });

  test('a saved System/Light/Dark choice wins over the old switch', () async {
    expect(await themeFor({'isDark': true, 'themeMode': 'system'}),
        ThemeMode.system);
  });
}
