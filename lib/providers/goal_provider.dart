import 'package:flutter/material.dart';
import '../db/goal_db_helper.dart';
import '../models/goal.dart';
import '../models/goal_contribution.dart';
import '../models/activity_log.dart';
import '../services/activity_logger.dart';

class GoalProvider with ChangeNotifier {
  List<Goal> _goals = [];
  final GoalDBHelper _dbHelper = GoalDBHelper();

  List<Goal> get goals => [..._goals];

  List<Goal> get activeGoals =>
      _goals.where((goal) => !goal.isAchieved).toList();

  List<Goal> get achievedGoals =>
      _goals.where((goal) => goal.isAchieved).toList();

  int get activeGoalCount => activeGoals.length;

  double get totalSaved =>
      _goals.fold(0.0, (sum, goal) => sum + goal.currentAmount);

  double get totalTarget => activeGoals.fold(
      0.0, (sum, goal) => sum + goal.targetAmount);

  Future<void> loadGoalsFromDB() async {
    try {
      _goals = await _dbHelper.getGoals();
      notifyListeners();
    } catch (e) {
      _goals = [];
      notifyListeners();
    }
  }

  Goal? getGoalById(String id) {
    try {
      return _goals.firstWhere((goal) => goal.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<bool> addGoal(Goal goal) async {
    try {
      final result = await _dbHelper.insertGoal(goal);
      if (result != -1) {
        _goals.add(goal);
        ActivityLogger().created(ActivityEntity.goal, goal.title,
            amount: goal.targetAmount);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateGoal(Goal goal) async {
    try {
      final result = await _dbHelper.updateGoal(goal);
      if (result != -1) {
        final index = _goals.indexWhere((g) => g.id == goal.id);
        if (index != -1) {
          _goals[index] = goal;
          ActivityLogger().updated(ActivityEntity.goal, goal.title,
              amount: goal.targetAmount);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteGoal(String id) async {
    try {
      String deletedTitle = 'Goal';
      for (final g in _goals) {
        if (g.id == id) {
          deletedTitle = g.title;
          break;
        }
      }
      final result = await _dbHelper.deleteGoal(id);
      if (result != -1) {
        _goals.removeWhere((goal) => goal.id == id);
        ActivityLogger().deleted(ActivityEntity.goal, deletedTitle);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Record a contribution toward a goal
  Future<bool> recordContribution(
      String goalId, GoalContribution contribution) async {
    try {
      final contributionResult =
          await _dbHelper.insertContribution(contribution);
      if (contributionResult == -1) return false;

      final goal = getGoalById(goalId);
      if (goal == null) return false;

      goal.currentAmount += contribution.amount;
      goal.modifiedOn = DateTime.now();

      final goalResult = await _dbHelper.updateGoal(goal);
      if (goalResult != -1) {
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<GoalContribution>> getContributionHistory(String goalId) async {
    try {
      return await _dbHelper.getContributionsByGoalId(goalId);
    } catch (e) {
      return [];
    }
  }
}
