import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/monthly_budget.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'monthly_budget.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE budgets(id INTEGER PRIMARY KEY AUTOINCREMENT, categoryName TEXT, month TEXT, budget REAL)',
        );
      },
    );
  }

  Future<void> insertBudget(MonthlyBudget budget) async {
    final db = await database;
    await db.insert(
      'budgets',
      {
        'categoryName': budget.categoryName,
        'month': budget.budgets.keys
            .first, // Assuming we are saving the first month for simplicity
        'budget': budget.budgets.values.first, // Save the first budget value
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MonthlyBudget>> getBudgets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('budgets');

    return List.generate(maps.length, (i) {
      return MonthlyBudget(
        categoryName: maps[i]['categoryName'],
        budgets: {maps[i]['month']: maps[i]['budget']},
      );
    });
  }
}
