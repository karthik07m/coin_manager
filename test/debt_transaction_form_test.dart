import 'package:coin_manager/models/account.dart';
import 'package:coin_manager/models/category.dart';
import 'package:coin_manager/models/debt.dart';
import 'package:coin_manager/models/debt_payment.dart';
import 'package:coin_manager/models/transaction.dart';
import 'package:coin_manager/providers/account_provider.dart';
import 'package:coin_manager/providers/category_provider.dart';
import 'package:coin_manager/providers/debt_provider.dart';
import 'package:coin_manager/providers/settings_provider.dart';
import 'package:coin_manager/providers/transaction_provider.dart';
import 'package:coin_manager/screens/transaction_form.dart';
import 'package:coin_manager/widgets/transaction_item.dart';
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
  Future<void> deleteTransaction(String id,
          {bool deleteReceipt = true}) async =>
      saved.removeWhere((t) => t.id == id);
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

class _Debts extends DebtProvider {
  @override
  DebtLink? linkFor(String transactionId) => transactionId == 'loan-tx'
      ? const DebtLink(debtId: 'loan', label: 'Lent to Sam')
      : null;
  final loan = Debt.createNew(
      id: 'loan',
      title: 'Emergency loan',
      amount: 100,
      amountPaid: 20,
      debtorName: 'Sam',
      isLiability: true,
      accountId: 4,
      dueDate: DateTime(2020))
    ..updateStatus();
  DebtPayment? payment;
  @override
  List<Debt> get debts => [loan];
  @override
  Debt? getDebtById(String id) => id == loan.id ? loan : null;
  @override
  Future<void> loadDebtsFromDB() async {}
  @override
  Future<bool> recordPayment(String debtId, DebtPayment value) async {
    payment = value;
    loan.amountPaid += value.amount;
    loan.updateStatus();
    notifyListeners();
    return true;
  }
}

void main() {
  testWidgets('lend money needs a name before the sheet confirms',
      (tester) async {
    SharedPreferences.setMockInitialValues({'enableNotifications': false});
    final settings = SettingsProvider();
    await settings.ready;
    final transactions = _Transactions();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<TransactionProvider>.value(
              value: transactions),
          ChangeNotifierProvider<DebtProvider>(create: (_) => _Debts()),
          ChangeNotifierProvider<CategoryProvider>(
              create: (_) => _Categories()),
          ChangeNotifierProvider<AccountProvider>(create: (_) => _Accounts()),
        ],
        child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: const TransactionForm())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Loans & repayments'));
    await tester.tap(find.text('Loans & repayments'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lend money'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    // Sheet stays open and the field shows the error.
    expect(find.text('Enter who owes you'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Ravi');
    await tester.pumpAndSettle();
    expect(find.text('Enter who owes you'), findsNothing);
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsNothing);
    expect(find.text('Lending to Ravi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a loan transaction row says who the money went to',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.ready;
    Widget row(String id) => TransactionItem(
        Transaction.createNew(
            id: id,
            title: 'Cash',
            amount: 50,
            categoryId: 9,
            accountId: 4,
            date: DateTime(2026, 9, 9),
            isExpense: true),
        _Categories().categories.first);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<DebtProvider>(create: (_) => _Debts()),
          ChangeNotifierProvider<AccountProvider>(create: (_) => _Accounts()),
        ],
        child: MaterialApp(
            home: Scaffold(body: Column(children: [row('loan-tx'), row('plain')])))));
    await tester.pump();
    expect(find.text('Lent to Sam'), findsOneWidget);
    expect(find.byIcon(Icons.handshake_outlined), findsOneWidget);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('repay overdue loan from form at ${width.toInt()}dp',
        (tester) async {
      SharedPreferences.setMockInitialValues({'enableNotifications': false});
      final settings = SettingsProvider();
      await settings.ready;
      final transactions = _Transactions();
      final debts = _Debts();
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final preview = GlobalKey();
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<TransactionProvider>.value(
                value: transactions),
            ChangeNotifierProvider<DebtProvider>.value(value: debts),
            ChangeNotifierProvider<CategoryProvider>(
                create: (_) => _Categories()),
            ChangeNotifierProvider<AccountProvider>(create: (_) => _Accounts()),
          ],
          child: RepaintBoundary(
              key: preview,
              child: MaterialApp(
                theme: ThemeData(useMaterial3: true),
                home: Builder(
                    builder: (context) => Scaffold(
                        body: TextButton(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => const TransactionForm())),
                            child: const Text('Add')))),
              ))));
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Loans & repayments'));
      await tester.tap(find.text('Loans & repayments'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repay existing debt'));
      await tester.pumpAndSettle();
      expect(find.text('Sam · Overdue'), findsOneWidget);
      await tester.ensureVisible(find.text('Confirm'));
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Repay Sam'), findsOneWidget);
      expect(find.textContaining('Remaining:'), findsOneWidget);
      await tester.ensureVisible(find.text('Use full remaining amount'));
      await tester.tap(find.text('Use full remaining amount'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(transactions.saved.single.amount, 80);
      expect(transactions.saved.single.accountId, 4);
      expect(transactions.saved.single.isRecurring, isFalse);
      expect(debts.payment!.transactionId, transactions.saved.single.id);
      expect(debts.loan.status, DebtStatus.paid);
      expect(find.byType(TransactionForm), findsNothing);
      expect(find.text('View debt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
