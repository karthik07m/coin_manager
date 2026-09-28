import 'dart:io';

import 'package:coin_manager/models/category.dart';
import 'package:coin_manager/providers/category_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The colour picked in the category editor must reach the database through
/// the provider the app actually registers, on both add and edit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    final tmp = await Directory.systemTemp.createTemp('cat_color');
    await databaseFactory.setDatabasesPath(tmp.path);
  });

  test('add and update keep the chosen colour', () async {
    final provider = CategoryProvider();
    await provider.addCategory(Category(
        name: 'Pets', icon: 'x.png', isExpense: true, colorValue: 0xFFEC407A));
    await provider.fetchAllCategories();
    var pets = provider.categories.firstWhere((c) => c.name == 'Pets');
    expect(pets.colorValue, 0xFFEC407A);

    await provider.updateCategory(Category(
        id: pets.id,
        name: 'Pets',
        icon: 'x.png',
        isExpense: true,
        colorValue: 0xFF42A5F5));
    pets = provider.categories.firstWhere((c) => c.name == 'Pets');
    expect(pets.colorValue, 0xFF42A5F5);
  });
}
