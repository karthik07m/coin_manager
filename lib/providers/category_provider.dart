import '../db/category_db_helper.dart';
import 'package:flutter/material.dart';
import '../models/category.dart';

class CategoryProvider with ChangeNotifier {
  // Maintain both the list and map for efficient access
  final List<Category> _categories = [];
  final Map<int, Category> _categoryMap = {};

  List<Category> get categories => List.unmodifiable(_categories);
  Map<int, Category> get categoryMap => Map.unmodifiable(_categoryMap);

  /// Fetch categories by `isExpense` type and update local cache
  Future<void> fetchCategories(bool isExpense) async {
    final data = await DBHelper().getCategories(isExpense);

    _categories
      ..clear()
      ..addAll(data.map((map) => Category.fromMap(map)));

    // Update the map for quick lookups
    _categoryMap
      ..clear()
      ..addEntries(
          _categories.map((category) => MapEntry(category.id!, category)));

    notifyListeners();
  }

  /// Fetch all categories regardless of `isExpense`
  Future<void> fetchAllCategories() async {
    final data = await DBHelper().getAllCategories();

    _categories
      ..clear()
      ..addAll(data.map((map) => Category.fromMap(map)));

    // Update the map for quick lookups
    _categoryMap
      ..clear()
      ..addEntries(
          _categories.map((category) => MapEntry(category.id!, category)));

    notifyListeners();
  }

  /// Add a new category and refresh the list for its type
  Future<void> addCategory(Category category) async {
    await DBHelper().insertCategory(
      category.name,
      category.icon,
      category.isExpense,
      budget: category.budget,
      createdOn: category.createdOn,
      modifiedOn: category.modifiedOn,
    );
    await fetchCategories(category.isExpense);
  }

  /// Delete a category by ID and remove it from cache
  Future<void> deleteCategory(int id) async {
    await DBHelper().deleteCategory(id);

    // Remove from both list and map
    _categories.removeWhere((category) => category.id == id);
    _categoryMap.remove(id);

    notifyListeners();
  }

  /// Update an existing category and refresh the list for its type
  Future<void> updateCategory(Category category) async {
    await DBHelper().updateCategory(
      category.id!,
      name: category.name,
      icon: category.icon,
      isExpense: category.isExpense,
      budget: category.budget,
      modifiedOn: category.modifiedOn,
    );
    await fetchCategories(category.isExpense);
  }

  /// Fetch category details by ID using the map for quick access
  Future<Category?> getCategoryDetailsById(int id) async {
    // Return from cache if available
    if (_categoryMap.containsKey(id)) {
      return _categoryMap[id];
    }

    // Otherwise, fetch from DB and cache it
    final map = await DBHelper().getCategoryDetailsById(id);
    if (map != null) {
      final category = Category.fromMap(map);
      _categoryMap[id] = category;
      return category;
    }
    return null;
  }
}
