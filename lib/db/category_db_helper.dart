import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import '../models/category.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();

  factory DBHelper() {
    return _instance;
  }

  DBHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'categories.db');

    return await openDatabase(
      path,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            icon TEXT NOT NULL,
            isExpense INTEGER NOT NULL,
            budget REAL,
            created_on TEXT,
            modified_on TEXT
          )
        ''');
        await _insertDefaultCategories(db);
      },
      version: 1,
    );
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final defaultCategories = [
      // Expense Categories
      {
        'name': 'Food',
        'icon': 'assets/categories/food.png',
        'isExpense': 1,
      },
      {
        'name': 'Groceries',
        'icon': 'assets/categories/groceries.png',
        'isExpense': 1,
      },
      {
        'name': 'Shopping',
        'icon': 'assets/categories/shopping.png',
        'isExpense': 1,
      },
      {
        'name': 'Transit',
        'icon': 'assets/categories/transport.png',
        'isExpense': 1,
      },
      {
        'name': 'Entertainment',
        'icon': 'assets/categories/entertainment.png',
        'isExpense': 1,
      },
      {
        'name': 'Utilities',
        'icon': 'assets/categories/bill.png',
        'isExpense': 1,
      },
      {
        'name': 'Travel',
        'icon': 'assets/categories/travel.png',
        'isExpense': 1,
      },
      {
        'name': 'Miscellaneous',
        'icon': 'assets/categories/other.png',
        'isExpense': 1,
      },
      // Income Categories
      {
        'name': 'Salary',
        'icon': 'assets/categories/salary.png',
        'isExpense': 0,
      },
      {
        'name': 'Stocks',
        'icon': 'assets/categories/stocks.png',
        'isExpense': 0,
      },
      {
        'name': 'Bonus',
        'icon': 'assets/categories/bonus.png',
        'isExpense': 0,
      },
      {
        'name': 'Miscellaneous',
        'icon': 'assets/categories/other.png',
        'isExpense': 0,
      },
    ];

    for (var category in defaultCategories) {
      await db.insert('categories', {
        ...category,
        'budget': null,
        'created_on': null,
        'modified_on': null,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getCategories(bool isExpense) async {
    final db = await database;
    return await db.query(
      'categories',
      where: 'isExpense = ?',
      whereArgs: [isExpense ? 1 : 0],
    );
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query('categories');
  }

  Future<int> insertCategory(String name, String icon, bool isExpense,
      {double? budget, String? createdOn, String? modifiedOn}) async {
    final db = await database;
    return await db.insert(
      'categories',
      {
        'name': name,
        'icon': icon,
        'isExpense': isExpense ? 1 : 0,
        'budget': budget,
        'created_on': createdOn,
        'modified_on': modifiedOn,
      },
    );
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateCategory(int id,
      {String? name,
      String? icon,
      bool? isExpense,
      double? budget,
      String? modifiedOn}) async {
    final db = await database;
    Map<String, dynamic> updatedFields = {};

    if (name != null) updatedFields['name'] = name;
    if (icon != null) updatedFields['icon'] = icon;
    if (isExpense != null) updatedFields['isExpense'] = isExpense ? 1 : 0;
    if (budget != null) updatedFields['budget'] = budget;
    if (modifiedOn != null) updatedFields['modified_on'] = modifiedOn;

    return await db.update(
      'categories',
      updatedFields,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getCategoryDetailsById(int id) async {
    final db = await database;
    final result = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }
}

class CategoryProvider with ChangeNotifier {
  final List<Category> _categories = [];
  final Map<int, Category> _categoryMap = {};

  List<Category> get categories => List.unmodifiable(_categories);
  Map<int, Category> get categoryMap => Map.unmodifiable(_categoryMap);

  Future<void> fetchCategories(bool isExpense) async {
    final data = await DBHelper().getCategories(isExpense);
    _categories
      ..clear()
      ..addAll(data.map((map) => Category.fromMap(map)));
    _categoryMap
      ..clear()
      ..addEntries(
          _categories.map((category) => MapEntry(category.id!, category)));
    notifyListeners();
  }

  Future<void> fetchAllCategories() async {
    final data = await DBHelper().getAllCategories();
    _categories
      ..clear()
      ..addAll(data.map((map) => Category.fromMap(map)));
    _categoryMap
      ..clear()
      ..addEntries(
          _categories.map((category) => MapEntry(category.id!, category)));
    notifyListeners();
  }

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

  Future<void> deleteCategory(int id) async {
    await DBHelper().deleteCategory(id);
    _categories.removeWhere((category) => category.id == id);
    _categoryMap.remove(id);
    notifyListeners();
  }

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

  Future<Category?> getCategoryDetailsById(int id) async {
    if (_categoryMap.containsKey(id)) return _categoryMap[id];
    final map = await DBHelper().getCategoryDetailsById(id);
    if (map != null) {
      final category = Category.fromMap(map);
      _categoryMap[id] = category;
      return category;
    }
    return null;
  }
}
