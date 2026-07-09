import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/goal.dart';
import '../models/goal_contribution.dart';

class GoalDBHelper {
  static final GoalDBHelper _instance = GoalDBHelper._internal();
  factory GoalDBHelper() => _instance;
  static Database? _db;

  GoalDBHelper._internal();

  // Goals table
  final String goalsTable = 'goals';
  final String columnId = 'id';
  final String columnTitle = 'title';
  final String columnTargetAmount = 'target_amount';
  final String columnCurrentAmount = 'current_amount';
  final String columnTargetDate = 'target_date';
  final String columnNotes = 'notes';
  final String columnCreatedOn = 'created_on';
  final String columnModifiedOn = 'modified_on';

  // Contributions table
  final String contributionsTable = 'goal_contributions';
  final String contributionColumnId = 'id';
  final String contributionColumnGoalId = 'goal_id';
  final String contributionColumnAmount = 'amount';
  final String contributionColumnDate = 'contribution_date';
  final String contributionColumnNotes = 'notes';
  final String contributionColumnCreatedOn = 'created_on';

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'goals.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  void _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $goalsTable(
        $columnId TEXT PRIMARY KEY,
        $columnTitle TEXT NOT NULL,
        $columnTargetAmount REAL NOT NULL,
        $columnCurrentAmount REAL DEFAULT 0,
        $columnTargetDate TEXT,
        $columnNotes TEXT,
        $columnCreatedOn TEXT NOT NULL,
        $columnModifiedOn TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $contributionsTable(
        $contributionColumnId TEXT PRIMARY KEY,
        $contributionColumnGoalId TEXT NOT NULL,
        $contributionColumnAmount REAL NOT NULL,
        $contributionColumnDate TEXT NOT NULL,
        $contributionColumnNotes TEXT,
        $contributionColumnCreatedOn TEXT NOT NULL,
        FOREIGN KEY ($contributionColumnGoalId) REFERENCES $goalsTable($columnId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_goal_id ON $contributionsTable($contributionColumnGoalId)
    ''');
  }

  // ===== GOAL OPERATIONS =====

  Future<int> insertGoal(Goal goal) async {
    var dbClient = await database;
    try {
      return await dbClient.insert(goalsTable, goal.toMap());
    } catch (e) {
      debugPrint('GoalDB error: $e');
      return -1;
    }
  }

  Future<List<Goal>> getGoals() async {
    var dbClient = await database;
    try {
      final List<Map<String, dynamic>> goals = await dbClient.query(
        goalsTable,
        orderBy: '$columnModifiedOn DESC',
      );
      return goals.map((map) => Goal.fromMap(map)).toList();
    } catch (e) {
      debugPrint('GoalDB error: $e');
      return [];
    }
  }

  Future<Goal?> getGoalById(String id) async {
    var dbClient = await database;
    try {
      List<Map<String, dynamic>> maps = await dbClient.query(
        goalsTable,
        where: '$columnId = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return Goal.fromMap(maps.first);
      }
    } catch (e) {
      debugPrint('GoalDB error: $e');
      // Return null if something goes wrong
    }
    return null;
  }

  Future<int> updateGoal(Goal goal) async {
    var dbClient = await database;
    try {
      return await dbClient.update(goalsTable, goal.toMap(),
          where: '$columnId = ?', whereArgs: [goal.id]);
    } catch (e) {
      debugPrint('GoalDB error: $e');
      return -1;
    }
  }

  Future<int> deleteGoal(String id) async {
    var dbClient = await database;
    try {
      await dbClient.delete(contributionsTable,
          where: '$contributionColumnGoalId = ?', whereArgs: [id]);
      return await dbClient
          .delete(goalsTable, where: '$columnId = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('GoalDB error: $e');
      return -1;
    }
  }

  // ===== CONTRIBUTION OPERATIONS =====

  Future<int> insertContribution(GoalContribution contribution) async {
    var dbClient = await database;
    try {
      return await dbClient.insert(contributionsTable, contribution.toMap());
    } catch (e) {
      debugPrint('GoalDB error: $e');
      return -1;
    }
  }

  Future<List<GoalContribution>> getContributionsByGoalId(
      String goalId) async {
    var dbClient = await database;
    try {
      final List<Map<String, dynamic>> contributions = await dbClient.query(
        contributionsTable,
        where: '$contributionColumnGoalId = ?',
        whereArgs: [goalId],
        orderBy: '$contributionColumnDate DESC',
      );
      return contributions
          .map((map) => GoalContribution.fromMap(map))
          .toList();
    } catch (e) {
      debugPrint('GoalDB error: $e');
      return [];
    }
  }

  Future<void> close() async {
    var dbClient = await database;
    try {
      await dbClient.close();
    } catch (e) {
      debugPrint('GoalDB error: $e');
      // Ignore errors on close
    }
  }
}
