import 'package:coin_manager/widgets/budget_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layout regressions at a narrow width.
///
/// 360dp is the width of the phones this app is most likely to be installed
/// on. Flutter reports an overflow as a FlutterError, which fails the test —
/// so these lock in that dense rows survive long names and large amounts
/// instead of being caught by eye, months later.
void main() {
  Widget harness(Widget child, {double width = 360}) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  Widget card({
    required String name,
    required double budget,
    required double spent,
    String symbol = r'$',
  }) {
    return BudgetProgressCard(
      categoryName: name,
      categoryIcon: 'assets/categories/bill.png',
      categoryColor: const Color(0xFF3498DB),
      budgetAmount: budget,
      spentAmount: spent,
      daysRemaining: 14,
      daysElapsed: 17,
      periodDays: 31,
      currencySymbol: symbol,
      transactionCount: 3,
    );
  }

  group('BudgetProgressCard at 360dp', () {
    testWidgets('ordinary values fit', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(card(
        name: 'Groceries',
        budget: 500,
        spent: 98.38,
      )));

      expect(tester.takeException(), isNull);
    });

    testWidgets('a long category name does not overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(card(
        name: 'Entertainment and Subscriptions',
        budget: 500,
        spent: 250,
      )));

      expect(tester.takeException(), isNull);
    });

    testWidgets('large amounts and a multi-character symbol fit',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(card(
        name: 'House Loan',
        budget: 1234567.89,
        spent: 987654.32,
        symbol: 'CHF ',
      )));

      expect(tester.takeException(), isNull);
    });

    testWidgets('an over-budget row still fits', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(card(
        name: 'Miscellaneous',
        budget: 100,
        spent: 4880.31,
      )));

      expect(tester.takeException(), isNull);
    });

    testWidgets('survives an even narrower 320dp screen', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(
        card(name: 'Entertainment', budget: 500, spent: 499.99),
        width: 320,
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('holds up at the largest accessibility text scale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: harness(card(
            name: 'Groceries',
            budget: 500,
            spent: 98.38,
          )),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
