import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transaction.dart' as trans_model;

class TransactionDBHelper {
  static final TransactionDBHelper _instance = TransactionDBHelper._internal();
  factory TransactionDBHelper() => _instance;
  static Database? _db;

  TransactionDBHelper._internal();

  final String tableName = 'transactions';
  final String columnId = 'id';
  final String columnTitle = 'title';
  final String columnAmount = 'amount';
  final String columnCategoryId = 'category_id';
  final String columnDate = 'date';
  final String columnCreatedOn = 'created_on';
  final String columnModifiedOn = 'modified_on';
  final String columnIsExpense = 'is_expense';

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'transactions.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  void _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName(
        $columnId TEXT PRIMARY KEY,
        $columnTitle TEXT,
        $columnAmount REAL,
        $columnCategoryId INTEGER,
        $columnDate TEXT,
        $columnCreatedOn TEXT,
        $columnModifiedOn TEXT,
        $columnIsExpense INTEGER
      )
    ''');
  }

  Future<int> insertTransaction(trans_model.Transaction transaction) async {
    var dbClient = await database;
    try {
      return await dbClient.insert(tableName, transaction.toMap());
    } catch (e) {
      return -1;
    }
  }

  Future<List<trans_model.Transaction>> getTransactions() async {
    var dbClient = await database;
    try {
      final List<Map<String, dynamic>> transactions =
          await dbClient.query(tableName, orderBy: '$columnDate DESC');
      return transactions
          .map((map) => trans_model.Transaction.fromMap(map))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<trans_model.Transaction?> getTransactionById(String id) async {
    var dbClient = await database;
    try {
      List<Map<String, dynamic>> maps = await dbClient.query(
        tableName,
        where: '$columnId = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return trans_model.Transaction.fromMap(maps.first);
      }
    } catch (e) {}
    return null;
  }

  Future<int> updateTransaction(trans_model.Transaction transaction) async {
    var dbClient = await database;
    try {
      return await dbClient.update(tableName, transaction.toMap(),
          where: '$columnId = ?', whereArgs: [transaction.id]);
    } catch (e) {
      return -1;
    }
  }

  Future<int> deleteTransaction(String id) async {
    var dbClient = await database;
    try {
      return await dbClient
          .delete(tableName, where: '$columnId = ?', whereArgs: [id]);
    } catch (e) {
      return -1;
    }
  }

  Future<double> _getTotalAmountByPeriod({
    required bool isExpense,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var dbClient = await database;
    try {
      List<String> whereClauses = ["$columnIsExpense = ${isExpense ? 1 : 0}"];
      List<dynamic> whereArgs = [];

      if (startDate != null) {
        whereClauses.add("$columnDate >= ?");
        whereArgs.add(startDate.toIso8601String());
      }
      if (endDate != null) {
        whereClauses.add("$columnDate <= ?");
        whereArgs.add(endDate.toIso8601String());
      }

      String whereClause = whereClauses.join(' AND ');
      String query =
          "SELECT SUM($columnAmount) AS total FROM $tableName WHERE $whereClause";

      List<Map<String, dynamic>> result =
          await dbClient.rawQuery(query, whereArgs);

      if (result.isNotEmpty && result.first['total'] != null) {
        return result.first['total'] as double;
      }

      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> getTotalExpensesByPeriod({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _getTotalAmountByPeriod(
      isExpense: true,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<double> getTotalIncomeByPeriod({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _getTotalAmountByPeriod(
      isExpense: false,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<trans_model.Transaction>> getTransactionsByType({
    bool? isExpense, // Nullable to fetch both income and expenses
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var dbClient = await database;
    try {
      List<String> whereClauses = [];
      List<dynamic> whereArgs = [];

      // Handle isExpense filter
      if (isExpense != null) {
        whereClauses.add("$columnIsExpense = ${isExpense ? 1 : 0}");
      }

      // Handle date range filter
      if (startDate != null && endDate != null) {
        whereClauses.add('$columnDate >= ? AND $columnDate <= ?');
        whereArgs
            .addAll([startDate.toIso8601String(), endDate.toIso8601String()]);
      }

      // Combine where clauses
      String? whereClause =
          whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

      final List<Map<String, dynamic>> transactions = await dbClient.query(
        tableName,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: '$columnDate DESC',
      );

      return transactions
          .map((map) => trans_model.Transaction.fromMap(map))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> close() async {
    var dbClient = await database;
    try {
      await dbClient.close();
    } catch (e) {}
  }
}
