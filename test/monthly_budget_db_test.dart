import 'dart:io';

import 'package:coin_manager/db/monthly_budget_db_helper.dart';
import 'package:coin_manager/models/budget_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Budget storage against a real SQLite database: the scope migration, the
/// legacy month-key fallback, and the copy/clear paths that move a user's
/// budget between months.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final budgets = MonthlyBudgetDBHelper();
  late Database db;

  setUp(() async {
    await MonthlyBudgetDBHelper.resetForTests();
    db = await budgets.openInMemoryDatabaseForTests();
    await db.delete('budget_totals');
    await db.delete('budget_values');
  });

  tearDown(() async {
    await MonthlyBudgetDBHelper.resetForTests();
  });

  group('scope', () {
    test('saved scope round-trips', () async {
      await budgets.saveMonthBudget(
        month: '2026-08',
        totalAmount: 1500,
        categoryBudgets: {'Food': 600, 'Groceries': 900},
        scope: BudgetScope.budgetedCategories,
      );

      expect(await budgets.getBudgetScope('2026-08'),
          BudgetScope.budgetedCategories);
      expect(await budgets.getTotalBudget('2026-08'), 1500);
      expect(await budgets.getBudget('Food', '2026-08'), 600);
    });

    test('a month with no row defaults to counting all expenses', () async {
      expect(
          await budgets.getBudgetScope('2026-12'), BudgetScope.allExpenses);
    });

    test('setTotalBudget preserves an existing scope', () async {
      // A replace-insert here would silently revert a category budget to
      // counting every expense.
      await budgets.saveMonthBudget(
        month: '2026-08',
        totalAmount: 1500,
        categoryBudgets: const {},
        scope: BudgetScope.budgetedCategories,
      );

      await budgets.setTotalBudget('2026-08', 1800);

      expect(await budgets.getTotalBudget('2026-08'), 1800);
      expect(await budgets.getBudgetScope('2026-08'),
          BudgetScope.budgetedCategories);
    });
  });

  group('v1 to v2 migration', () {
    test('adds scope and leaves existing budgets readable', () async {
      await MonthlyBudgetDBHelper.resetForTests();
      // A file, not :memory: — the database must survive being reopened at
      // the higher version for the migration to run against real data.
      final path = join(
        Directory.systemTemp.createTempSync('coinly_migration').path,
        'monthly_budget.db',
      );
      final v1 =
          await budgets.openInMemoryDatabaseForTests(version: 1, path: path);
      await v1.insert('budget_totals', {
        'month_key': '2026-07',
        'total_amount': 4800.0,
      });
      await v1.insert('budget_values', {
        'category_name': 'Food',
        'month_key': '2026-07',
        'amount': 200.0,
      });
      await v1.close();

      await budgets.reopenAtVersionForTests(path, 2);

      // The user's figures survive, and the new column reads as the old
      // whole-spending behaviour rather than silently changing meaning.
      expect(await budgets.getTotalBudget('2026-07'), 4800);
      expect(await budgets.getBudget('Food', '2026-07'), 200);
      expect(
          await budgets.getBudgetScope('2026-07'), BudgetScope.allExpenses);
    });
  });

  group('month tracking', () {
    test('budgeted months are listed newest first', () async {
      await budgets.setTotalBudget('2026-06', 100);
      await budgets.setTotalBudget('2026-08', 300);
      await budgets.setTotalBudget('2026-07', 200);

      expect(await budgets.getBudgetedMonthKeys(),
          ['2026-08', '2026-07', '2026-06']);
    });

    test('months with a zero budget are not counted as budgeted', () async {
      await budgets.setTotalBudget('2026-06', 0);
      expect(await budgets.getBudgetedMonthKeys(), isEmpty);
    });

    test('finds the latest month before a given one, across a year', () async {
      await budgets.setTotalBudget('2025-12', 100);
      await budgets.setTotalBudget('2026-01', 200);

      expect(await budgets.latestBudgetedMonthBefore('2026-02'), '2026-01');
      expect(await budgets.latestBudgetedMonthBefore('2026-01'), '2025-12');
      expect(await budgets.latestBudgetedMonthBefore('2025-12'), isNull);
    });
  });

  group('copy and clear', () {
    test('copy carries amounts and scope, replacing the destination',
        () async {
      await budgets.saveMonthBudget(
        month: '2026-08',
        totalAmount: 1500,
        categoryBudgets: {'Food': 600},
        scope: BudgetScope.budgetedCategories,
      );
      // A category the source does not have must not survive the copy.
      await budgets.saveMonthBudget(
        month: '2026-09',
        totalAmount: 99,
        categoryBudgets: {'Travel': 99},
        scope: BudgetScope.allExpenses,
      );

      await budgets.copyBudget(fromMonth: '2026-08', toMonth: '2026-09');

      expect(await budgets.getTotalBudget('2026-09'), 1500);
      expect(await budgets.getBudget('Food', '2026-09'), 600);
      expect(await budgets.getBudget('Travel', '2026-09'), 0);
      expect(await budgets.getBudgetScope('2026-09'),
          BudgetScope.budgetedCategories);
    });

    test('clearing a month leaves other months untouched', () async {
      await budgets.setTotalBudget('2026-08', 1500);
      await budgets.setBudget('Food', '2026-08', 600);
      await budgets.setTotalBudget('2026-09', 1200);

      await budgets.clearMonth('2026-08');

      expect(await budgets.getTotalBudget('2026-08'), 0);
      expect(await budgets.getBudget('Food', '2026-08'), 0);
      expect(await budgets.getTotalBudget('2026-09'), 1200);
    });
  });

  group('legacy month keys', () {
    test('pre-migration rows keyed by month number are still readable',
        () async {
      // Old installs stored August as "8" rather than "2026-08".
      await db.insert(
          'budget_totals', {'month_key': '8', 'total_amount': 999.0});
      await db.insert('budget_values',
          {'category_name': 'Food', 'month_key': '8', 'amount': 111.0});

      expect(await budgets.getTotalBudget('2026-08'), 999);
      expect(await budgets.getBudget('Food', '2026-08'), 111);
    });

    test('an explicit month wins over a legacy row', () async {
      await db.insert(
          'budget_totals', {'month_key': '8', 'total_amount': 999.0});
      await budgets.setTotalBudget('2026-08', 1500);

      expect(await budgets.getTotalBudget('2026-08'), 1500);
    });

    test('clearing a month also removes its legacy row', () async {
      // Otherwise the fallback resurrects a budget the user just deleted.
      await db.insert(
          'budget_totals', {'month_key': '8', 'total_amount': 999.0});
      await budgets.setTotalBudget('2026-08', 1500);

      await budgets.clearMonth('2026-08');

      expect(await budgets.getTotalBudget('2026-08'), 0);
    });

    test('a legacy row leaks across years — known limitation', () async {
      await db.insert(
          'budget_totals', {'month_key': '8', 'total_amount': 999.0});

      // Documents real behaviour: "8" cannot say which year it belonged to,
      // so every August reads it until that month is saved explicitly.
      expect(await budgets.getTotalBudget('2027-08'), 999);
      expect(await budgets.getTotalBudget('2027-09'), 0);
    });
  });
}
