import 'dart:io';
import 'dart:ui' as ui;

import 'package:coin_manager/main.dart';
import 'package:coin_manager/models/category.dart';
import 'package:coin_manager/models/transaction.dart';
import 'package:coin_manager/providers/account_provider.dart';
import 'package:coin_manager/providers/ai_assistant_provider.dart';
import 'package:coin_manager/providers/category_provider.dart';
import 'package:coin_manager/providers/debt_provider.dart';
import 'package:coin_manager/providers/monthly_budget_provider.dart';
import 'package:coin_manager/providers/settings_provider.dart';
import 'package:coin_manager/providers/transaction_provider.dart';
import 'package:coin_manager/screens/ai_assistant_screen.dart';
import 'package:coin_manager/screens/balance_card.dart';
import 'package:coin_manager/screens/monthly_budget_screen.dart';
import 'package:coin_manager/screens/manage_budget.dart';
import 'package:coin_manager/utilities/constants.dart';
import 'package:coin_manager/utilities/theme_helper.dart';
import 'package:coin_manager/widgets/custom_nav_bar.dart';
import 'package:coin_manager/widgets/transaction_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Categories extends CategoryProvider {
  @override
  List<Category> get categories => [
        Category(
            id: 1,
            name: 'Food & drink',
            icon: 'assets/categories/tea.png',
            isExpense: true)
      ];
}

class _Accounts extends AccountProvider {
  @override
  bool get isLoaded => true;
}

class _Budgets extends MonthlyBudgetProvider {
  final loadedMonths = <String>[];
  @override
  Future<void> loadMonthlyData(String month) async {
    loadedMonths.add(month);
  }

  @override
  double getTotalBudget(String month) => 2500;
  @override
  double getBudget(String categoryName, String month) => 500;
  @override
  Future<double> fetchTotalBudget(String month) async => 2500;
}

class _BudgetTransactions extends TransactionProvider {
  @override
  Future<void> loadTransactionsFromDB(
      {bool? isExpense,
      DateTime? startDate,
      DateTime? endDate,
      DateTime? totalsStartDate,
      DateTime? totalsEndDate}) async {}
  @override
  Future<double> getExpenseTotalForRange(
          {required DateTime startDate, required DateTime endDate}) async =>
      100;
}

void main() {
  const reviewDir = String.fromEnvironment('UI_REVIEW_DIR');
  const fontDir = String.fromEnvironment('UI_FONT_DIR');
  final captureKey = GlobalKey();
  late SettingsProvider settings;
  late AiAssistantProvider assistant;
  late ThemeData lightTheme;
  late ThemeData darkTheme;

  Future<void> initialize(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(
        {'isFirstLaunch': true, 'enableNotifications': false});
    settings = SettingsProvider();
    await settings.ready;
    assistant = AiAssistantProvider();
    addTearDown(settings.dispose);
    addTearDown(assistant.dispose);
    // Use the application's real themes, including its dynamic-color fallback.
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    lightTheme = app.theme!;
    darkTheme = app.darkTheme!;
    if (fontDir.isNotEmpty) {
      for (final family in ['Roboto', 'Ahem', 'MaterialIcons']) {
        final loader = FontLoader(family);
        final file = family == 'MaterialIcons'
            ? 'MaterialIcons-Regular.otf'
            : 'Roboto-Regular.ttf';
        loader.addFont(Future.value(
            ByteData.sublistView(File('$fontDir/$file').readAsBytesSync())));
        await loader.load();
      }
      // Load the workspace's bundled font when present. Standalone themed
      // styles also need an explicit family in Flutter's Ahem test renderer.
      final hasInter = File('assets/fonts/Inter-Regular.ttf').existsSync();
      if (hasInter) {
        final loader = FontLoader('Inter');
        for (final weight in [
          'Regular',
          'Medium',
          'SemiBold',
          'Bold',
          'ExtraBold'
        ]) {
          loader.addFont(Future.value(ByteData.sublistView(
              File('assets/fonts/Inter-$weight.ttf').readAsBytesSync())));
        }
        await loader.load();
      }
      final reviewFamily = hasInter ? 'Inter' : 'Roboto';
      final buttonText = WidgetStatePropertyAll(
          AppTextStyles.button.copyWith(fontFamily: reviewFamily));
      ThemeData withReviewFonts(ThemeData theme) => theme.copyWith(
            appBarTheme: theme.appBarTheme.copyWith(
                titleTextStyle: theme.appBarTheme.titleTextStyle
                    ?.copyWith(fontFamily: reviewFamily)),
            textButtonTheme: TextButtonThemeData(
                style: (theme.textButtonTheme.style ?? const ButtonStyle())
                    .copyWith(textStyle: buttonText)),
            outlinedButtonTheme: OutlinedButtonThemeData(
                style: (theme.outlinedButtonTheme.style ?? const ButtonStyle())
                    .copyWith(textStyle: buttonText)),
            filledButtonTheme: FilledButtonThemeData(
                style: (theme.filledButtonTheme.style ?? const ButtonStyle())
                    .copyWith(textStyle: buttonText)),
          );
      lightTheme = withReviewFonts(lightTheme);
      darkTheme = withReviewFonts(darkTheme);
    }
  }

  Widget harness(Widget screen,
          {bool dark = false,
          double scale = 1,
          int tab = 0,
          ValueChanged<int>? onTab,
          MonthlyBudgetProvider? budgets,
          TransactionProvider? transactions,
          RouteFactory? onGenerateRoute}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<AiAssistantProvider>.value(value: assistant),
          ChangeNotifierProvider<AccountProvider>(create: (_) => _Accounts()),
          ChangeNotifierProvider<DebtProvider>(create: (_) => DebtProvider()),
          ChangeNotifierProvider<CategoryProvider>(
              create: (_) => _Categories()),
          ChangeNotifierProvider<TransactionProvider>(
              create: (_) => transactions ?? TransactionProvider()),
          ChangeNotifierProvider<MonthlyBudgetProvider>(
              create: (_) => budgets ?? MonthlyBudgetProvider()),
        ],
        child: MaterialApp(
          theme: dark ? darkTheme : lightTheme,
          onGenerateRoute: onGenerateRoute,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: RepaintBoundary(
              key: captureKey,
              child: Scaffold(
                body: screen,
                bottomNavigationBar: CustomNavBar(
                    selectedIndex: tab, onItemSelected: onTab ?? (_) {}),
              )),
        ),
      );

  Future<void> capture(WidgetTester tester, String name) async {
    if (reviewDir.isEmpty) return;
    await tester.runAsync(() async {
      await precacheImage(const AssetImage('assets/categories/tea.png'),
          captureKey.currentContext!);
    });
    await tester.pumpAndSettle();
    // Raw RichText spans use the platform fallback in production, but Ahem
    // in widget tests. Supply that missing fallback for review images only.
    final family = File('assets/fonts/Inter-Regular.ttf').existsSync()
        ? 'Inter'
        : 'Roboto';
    for (final element in find
        .descendant(of: find.byKey(captureKey), matching: find.byType(RichText))
        .evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      if (paragraph.text.style?.fontFamily == null) {
        paragraph.text = TextSpan(
            style: TextStyle(fontFamily: family), children: [paragraph.text]);
      }
    }
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = captureKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('$reviewDir/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget balance({double income = 5200, ValueChanged<DateTime>? onMonth}) =>
      BalanceCard(
        screenWidth: 390,
        totalIncome: income,
        totalExpenses: 1842.50,
        previousMonthExpenses: 2100,
        selectedMonth: DateTime(2026, 9),
        onMonthChanged: onMonth ?? (_) {},
      );

  for (final dark in [false, true]) {
    testWidgets('overview components render in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
      await initialize(tester, 390);
      await tester.pumpWidget(harness(
          Builder(
              builder: (context) => ListView(
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text('Your overview',
                              style: AppTextStyles.h2
                                  .copyWith(color: context.textPrimary))),
                      balance(),
                      Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text('Recent transactions',
                              style: AppTextStyles.bodyLarge
                                  .copyWith(fontWeight: FontWeight.w700))),
                      for (final (name, amount) in [
                        ('Morning coffee', 5.50),
                        ('Weekly groceries', 86.40)
                      ])
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TransactionItem(
                                Transaction.createNew(
                                    id: name,
                                    title: name,
                                    amount: amount,
                                    categoryId: 1,
                                    accountId: 1,
                                    date: DateTime(2026, 9, 11, 9, 30),
                                    isExpense: true),
                                _Categories().categories.first)),
                    ],
                  )),
          dark: dark));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, 'overview-${dark ? 'dark' : 'light'}');
    });

    testWidgets(
        'assistant actions preserve prefill in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
      await initialize(tester, 390);
      await tester
          .pumpWidget(harness(const AiAssistantScreen(), dark: dark, tab: 4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, 'assistant-${dark ? 'dark' : 'light'}');
      await tester.tap(find.text('Add expense'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Add expense ');
      expect(assistant.messages, isEmpty);
      expect(find.byTooltip('Send'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'budget has one edit action and refreshes after the editor returns',
      (tester) async {
    await initialize(tester, 390);
    final budgets = _Budgets();
    RouteSettings? openedRoute;
    await tester.pumpWidget(harness(const MonthlyBudgetScreen(),
        tab: 2,
        budgets: budgets,
        transactions: _BudgetTransactions(), onGenerateRoute: (route) {
      openedRoute = route;
      return MaterialPageRoute<void>(
          builder: (context) => Scaffold(
              body: Center(
                  child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done editing')))));
    }));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Edit budget'), findsOneWidget);
    expect(find.text('Manage'), findsNothing);
    expect(find.byTooltip('Edit budget'), findsNothing);
    await capture(tester, 'budget-light');
    final loadsBefore = budgets.loadedMonths.length;
    await tester.tap(find.text('Edit budget'));
    await tester.pumpAndSettle();
    expect(openedRoute!.name, '/manageBudget');
    final args = openedRoute!.arguments! as ManageBudgetArgs;
    expect(args.initialMonth!.year, DateTime.now().year);
    expect(args.initialMonth!.month, DateTime.now().month);
    expect(args.autoAllocate, isFalse);
    await tester.tap(find.text('Done editing'));
    await tester.pumpAndSettle();
    expect(budgets.loadedMonths.length, greaterThan(loadsBefore));
    expect(find.text('Edit budget'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all six navigation destinations remain reachable at 320dp',
      (tester) async {
    await initialize(tester, 320);
    final selected = <int>[];
    await tester
        .pumpWidget(harness(const SizedBox(), scale: 1.5, onTab: selected.add));
    for (final label in [
      'Home',
      'List',
      'Budget',
      'Charts',
      'AI',
      'Settings'
    ]) {
      await tester.tap(find.text(label));
    }
    expect(selected, [0, 1, 2, 3, 4, 5]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('balance handles large values and month selection at 320dp',
      (tester) async {
    await initialize(tester, 320);
    DateTime? selected;
    await tester.pumpWidget(harness(
        ListView(children: [
          balance(income: 123456789, onMonth: (date) => selected = date)
        ]),
        scale: 1.5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Sep 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aug'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2026, 8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('assistant scrolls at 320dp with large text and keyboard open',
      (tester) async {
    await initialize(tester, 320);
    await tester
        .pumpWidget(harness(const AiAssistantScreen(), scale: 1.5, tab: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Send').hitTestable(), findsOneWidget);
  });
}
