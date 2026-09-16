import 'package:coin_manager/models/category.dart';
import 'package:coin_manager/utilities/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unset colour is a stable palette entry keyed on id', () {
    final a = Category(id: 7, name: 'Food', icon: 'x', isExpense: true);
    final b = Category(id: 7, name: 'Renamed', icon: 'y', isExpense: true);
    expect(a.color, b.color);
    expect(AppColors.categoryPalette, contains(a.color));
    expect(Category(id: 8, name: 'Rent', icon: 'x', isExpense: true).color,
        isNot(a.color));
  });

  test('chosen colour survives a map round-trip', () {
    final c = Category(
        id: 1, name: 'Fun', icon: 'x', isExpense: true, colorValue: 0xFFEC407A);
    final back = Category.fromMap(c.toMap());
    expect(back.colorValue, 0xFFEC407A);
    expect(back.color.toARGB32(), 0xFFEC407A);
  });
}
