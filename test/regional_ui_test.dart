import 'package:coin_manager/models/account.dart';
import 'package:coin_manager/models/category.dart';
import 'package:coin_manager/models/regional_preferences.dart';
import 'package:coin_manager/models/transaction.dart';
import 'package:coin_manager/providers/account_provider.dart';
import 'package:coin_manager/providers/category_provider.dart';
import 'package:coin_manager/providers/debt_provider.dart';
import 'package:coin_manager/providers/settings_provider.dart';
import 'package:coin_manager/providers/transaction_provider.dart';
import 'package:coin_manager/screens/finance_templates_screen.dart';
import 'package:coin_manager/screens/goal_form_screen.dart';
import 'package:coin_manager/screens/regional_preferences_screen.dart';
import 'package:coin_manager/screens/transaction_form.dart';
import 'package:coin_manager/widgets/calculator_field.dart';
import 'package:coin_manager/widgets/india_setup_card.dart';
import 'package:coin_manager/widgets/yearly_expenses_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Transactions extends TransactionProvider {
  final saved = <Transaction>[];
  final requests = <(int, int)>[];
  @override
  Future<void> addTransaction(Transaction transaction) async =>
      saved.add(transaction);
  @override
  Future<int?> getLastCategoryForTitle(String title, bool isExpense) async =>
      null;
  @override
  Future<List<double>> monthlyExpenseTotals(int year,
      {int startMonth = 1}) async {
    requests.add((year, startMonth));
    return List.filled(12, 100.0);
  }
}

class _Categories extends CategoryProvider {
  @override
  List<Category> get categories => [
        Category(
            id: 9,
            name: 'Groceries',
            icon: 'assets/categories/food.png',
            isExpense: true),
        Category(
            id: 10,
            name: 'Bill',
            icon: 'assets/categories/bill.png',
            isExpense: true),
      ];
  @override
  Map<int, Category> get categoryMap => {for (final c in categories) c.id!: c};
  @override
  Future<void> fetchCategories(bool isExpense) async {}
}

class _Accounts extends AccountProvider {
  @override
  bool get isLoaded => true;
  @override
  List<Account> get accounts => [
        Account(
            id: 4,
            name: 'Bank',
            icon: 'assets/categories/bank.png',
            color: '#2ECC71',
            currency: 'INR',
            isDefault: true,
            createdOn: DateTime(2026),
            modifiedOn: DateTime(2026))
      ];
  @override
  Account? get defaultAccount => accounts.first;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsProvider settings;
  late _Transactions transactions;

  Future<void> initialize() async {
    SharedPreferences.setMockInitialValues({'enableNotifications': false});
    settings = SettingsProvider();
    await settings.ready;
    transactions = _Transactions();
  }

  Widget harness(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<TransactionProvider>.value(
              value: transactions),
          ChangeNotifierProvider<CategoryProvider>(
              create: (_) => _Categories()),
          ChangeNotifierProvider<AccountProvider>(create: (_) => _Accounts()),
          ChangeNotifierProvider<DebtProvider>(create: (_) => DebtProvider()),
        ],
        child: MaterialApp(theme: ThemeData(useMaterial3: true), home: child),
      );

  void narrow(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('canceling India setup leaves preferences unchanged',
      (tester) async {
    await initialize();
    narrow(tester);
    await tester.pumpWidget(harness(const Scaffold(body: IndiaSetupCard())));
    await tester.tap(find.text('Personalize'));
    await tester.pumpAndSettle();
    expect(find.text('April'), findsOneWidget);
    expect(settings.regionalPreferences.indiaTemplates, isFalse);
    expect(settings.regionalPreferences.financialYearStartMonth, 1);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(settings.shouldSuggestIndiaSetup, isTrue);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Personalize for India'), findsNothing);
    expect(settings.shouldSuggestIndiaSetup, isFalse);
  });

  testWidgets('saving suggested setup applies choices explicitly',
      (tester) async {
    await initialize();
    narrow(tester);
    await tester.pumpWidget(harness(const Scaffold(body: IndiaSetupCard())));
    await tester.tap(find.text('Personalize'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Save preferences').hitTestable(), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();
    expect(settings.regionalPreferences.indiaTemplates, isTrue);
    expect(settings.regionalPreferences.financialYearStartMonth, 4);
    expect(settings.shouldSuggestIndiaSetup, isFalse);
    expect(find.byType(FinanceTemplatesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all currencies can access templates without India assumptions',
      (tester) async {
    await initialize();
    narrow(tester);
    await settings.setCurrency('USD', r'$');
    await tester.pumpWidget(harness(const FinanceTemplatesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Milk bill'), findsNothing);
    await settings.setRegionalPreferences(const RegionalPreferences(
        indiaTemplates: true, indiaSetupHandled: true));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Milk bill').hitTestable(), 220);
    expect(find.text('Milk bill'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'payment template opens a recurring draft and cancel writes nothing',
      (tester) async {
    await initialize();
    narrow(tester);
    await settings.setRegionalPreferences(const RegionalPreferences(
        indiaTemplates: true, indiaSetupHandled: true));
    await tester.pumpWidget(harness(const FinanceTemplatesScreen()));
    await tester.scrollUntilVisible(find.text('Milk bill').hitTestable(), 220);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milk bill'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionForm), findsOneWidget);
    expect(find.text('Milk bill'), findsOneWidget);
    final state =
        tester.state<TransactionFormState>(find.byType(TransactionForm));
    expect(find.textContaining('· monthly'), findsOneWidget);
    expect(state.selectedCategory, 9);
    expect(state.selectedAccount, 4);
    expect(transactions.saved, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(transactions.saved, isEmpty);
  });

  testWidgets('savings template opens an editable title with selected currency',
      (tester) async {
    await initialize();
    narrow(tester);
    await tester.pumpWidget(harness(const FinanceTemplatesScreen()));
    await tester.scrollUntilVisible(
        find.text('Emergency fund').hitTestable(), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emergency fund'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalFormScreen), findsOneWidget);
    expect(find.text('Emergency fund'), findsOneWidget);
    final fields = tester.widgetList<CalculatorTextFormField>(
        find.byType(CalculatorTextFormField));
    expect(fields.map((field) => field.currencySymbol), everyElement('₹'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('financial-year bar navigates to January in the following year',
      (tester) async {
    await initialize();
    narrow(tester);
    DateTime? viewedMonth;
    await tester.pumpWidget(harness(Scaffold(
        body: SingleChildScrollView(
            child: YearlyExpensesChart(
                year: 2025,
                highlightMonth: 4,
                startMonth: 4,
                onViewMonth: (month) => viewedMonth = month)))));
    await tester.pumpAndSettle();
    expect(transactions.requests.last, (2025, 4));
    expect(find.text('2025–2026'), findsOneWidget);
    final rect = tester.getRect(find.byType(BarChart));
    await tester.tapAt(Offset(
        rect.left + rect.width * 9.5 / 12, rect.top + rect.height * 0.4));
    await tester.pumpAndSettle();
    expect(find.text('Jan 2026'), findsOneWidget);
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(viewedMonth, DateTime(2026, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('regional preferences fit a 320dp screen with large text',
      (tester) async {
    await initialize();
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: const RegionalPreferencesScreen(suggestIndia: true))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Save preferences').hitTestable(), 200);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
