import 'dart:ui';

import '../utilities/constants.dart';

class Category {
  final int? id;
  final String name;
  final String icon;
  final bool isExpense;
  final double? budget;

  /// ARGB value chosen by the user, or null for the palette default.
  final int? colorValue;
  final String? createdOn;
  final String? modifiedOn;

  Category({
    this.id,
    required this.name,
    required this.icon,
    required this.isExpense,
    this.budget,
    this.colorValue,
    this.createdOn,
    this.modifiedOn,
  });

  /// The colour this category renders in everywhere. Unset categories get a
  /// stable palette entry keyed on their id, so nothing shifts between months.
  Color get color => colorValue != null
      ? Color(colorValue!)
      : defaultColorFor(id ?? name.hashCode);

  static Color defaultColorFor(int key) =>
      AppColors.categoryPalette[key.abs() % AppColors.categoryPalette.length];

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      isExpense: map['isExpense'] == 1,
      budget: map['budget'],
      colorValue: map['color'],
      createdOn: map['created_on'],
      modifiedOn: map['modified_on'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'isExpense': isExpense ? 1 : 0,
      'budget': budget,
      'color': colorValue,
      'created_on': createdOn,
      'modified_on': modifiedOn,
    };
  }
}
