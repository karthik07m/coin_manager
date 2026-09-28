import 'dart:ui';

import 'package:coin_manager/models/category.dart';
import 'package:coin_manager/models/category_amount.dart';
import 'package:coin_manager/providers/transaction_provider.dart';
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

  test('pie slices sharing a default colour get told apart', () {
    CategoryAmount slice(int id, double amount, {Color? color}) =>
        CategoryAmount(
            id: id,
            name: '$id',
            icon: 'x',
            color: color ?? Category.defaultColorFor(id),
            amount: amount);
    // 1 and 13 map to the same palette entry.
    expect(Category.defaultColorFor(1), Category.defaultColorFor(13));

    final out = TransactionProvider.distinctSliceColors(
        [slice(13, 50), slice(1, 500)],
        chosenColorIds: {});
    expect(out.map((s) => s.id), [13, 1], reason: 'order preserved');
    expect(out[1].color, Category.defaultColorFor(1), reason: 'bigger keeps');
    expect(out[0].color, isNot(out[1].color));

    // A colour the user picked is never changed, even when it clashes.
    final picked = TransactionProvider.distinctSliceColors(
        [slice(13, 50, color: Category.defaultColorFor(1)), slice(1, 500)],
        chosenColorIds: {13});
    expect(picked[0].color, Category.defaultColorFor(1));
  });
}
