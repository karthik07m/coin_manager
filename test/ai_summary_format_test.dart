import 'package:coin_manager/db/transaction_db_helper.dart';
import 'package:coin_manager/models/ai_intent.dart';
import 'package:coin_manager/models/category.dart';
import 'package:coin_manager/models/transaction.dart' as model;
import 'package:coin_manager/services/ai_summary_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The habits answer, built from a real database, using the shape of month
/// that produced bad advice: a mortgage and rent both falling on a Saturday.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final helper = TransactionDBHelper();
  final service = AiSummaryService();
  late Database db;

  final categories = [
    Category(id: 1, name: 'House Loan', icon: 'h.png', isExpense: true),
    Category(id: 2, name: 'House Rent', icon: 'r.png', isExpense: true),
    Category(id: 3, name: 'Dining Out', icon: 'd.png', isExpense: true),
    Category(id: 4, name: 'Salary', icon: 's.png', isExpense: false),
  ];

  Future<void> add(double amount, int categoryId, DateTime date,
      {bool isExpense = true, bool recurring = false}) async {
    await helper.insertTransaction(model.Transaction.createNew(
      id: 'x$categoryId$amount${date.month}_${date.day}',
      title: 'x',
      amount: amount,
      categoryId: categoryId,
      accountId: 1,
      date: date,
      isExpense: isExpense,
      isRecurring: recurring,
    ));
  }

  setUp(() async {
    await TransactionDBHelper.resetForTests();
    db = await helper.openInMemoryDatabaseForTests();
    await db.delete('transactions');
  });

  tearDown(() async => TransactionDBHelper.resetForTests());

  Future<String> summary() {
    return service.buildSummary(
      request: AiSummaryRequest(
        metric: AiSummaryMetric.spendingHabits,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 20),
      ),
      categories: categories,
      currencySymbol: r'$',
      currencyCode: 'USD',
    );
  }

  test('a mortgage is an essential, not lifestyle spending', () async {
    // Aug 1 2026 is a Saturday: the fixed bills land on a weekend.
    await add(2000, 1, DateTime(2026, 8, 1), recurring: true);
    await add(1928.95, 2, DateTime(2026, 8, 1), recurring: true);
    await add(200, 3, DateTime(2026, 8, 5));
    await add(6000, 4, DateTime(2026, 8, 1), isExpense: false);

    final text = await summary();

    // Lifestyle should be the $200 dinner, not the $3,928 of housing.
    expect(text, contains('Lifestyle \$200.00'));
    expect(
      text,
      isNot(contains('reviewing House Loan')),
      reason: 'a mortgage must never be described as discretionary',
    );
  });

  test('fixed bills on a weekend do not become weekend habit', () async {
    await add(2000, 1, DateTime(2026, 8, 1), recurring: true);
    await add(50, 3, DateTime(2026, 8, 3));
    await add(50, 3, DateTime(2026, 8, 10));

    final text = await summary();

    // The absurd figure came from dividing housing across weekend days.
    expect(text, isNot(contains('1698%')));
    final match = RegExp(r'Weekends run (\d+)% higher').firstMatch(text);
    if (match != null) {
      expect(int.parse(match.group(1)!), lessThan(500),
          reason: 'weekend comparison should reflect discretionary spending');
    }
  });

  test('advice is numbered, capped, and free of emoji bullets', () async {
    await add(2000, 1, DateTime(2026, 8, 1), recurring: true);
    await add(900, 3, DateTime(2026, 8, 4));
    await add(6000, 4, DateTime(2026, 8, 1), isExpense: false);

    final text = await summary();

    expect(text, contains('Suggestions'));
    expect(text, isNot(contains('Advisor Tips')));
    expect(text, isNot(contains('━━━')));

    final numbered =
        RegExp(r'^\d+\. ', multiLine: true).allMatches(text).length;
    expect(numbered, greaterThan(0));
    expect(numbered, lessThanOrEqualTo(4));

    for (final emoji in ['💡', '🎯', '☕', '📈', '🚨', '📌']) {
      expect(text, isNot(contains(emoji)), reason: '$emoji should be gone');
    }
  });

  test('comparison explains the delta, not just lists it', () async {
    // Fixed bill both months; dining doubled via one big dinner.
    await add(2000, 1, DateTime(2026, 8, 1), recurring: true);
    await add(2000, 1, DateTime(2026, 7, 1), recurring: true);
    await add(40, 3, DateTime(2026, 8, 3));
    await add(160, 3, DateTime(2026, 8, 5));
    await add(50, 3, DateTime(2026, 7, 3));
    await add(50, 3, DateTime(2026, 7, 5));

    final text = await service.buildSummary(
      request: AiSummaryRequest(
        metric: AiSummaryMetric.monthComparison,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
      ),
      categories: categories,
      currencySymbol: r'$',
      currencyCode: 'USD',
    );

    expect(text, startsWith('August vs July'));
    // Rent is compared as a fixed bill, not folded into behaviour.
    expect(text, contains('Fixed bills: \$2,000.00 vs \$2,000.00'));
    expect(text, contains('Day-to-day spending: \$200.00 vs \$100.00'));
    // The +\$100 on dining is attributed to the single \$160 dinner.
    expect(text, contains('Dining Out +\$100.00 — mostly one \$160.00 purchase'));
    expect(text, contains('driven mostly by Dining Out'));
  });

  test('section headings are plain, not ascii art', () async {
    await add(100, 3, DateTime(2026, 8, 4));

    final text = await summary();

    expect(text, contains('Overview'));
    expect(text, contains('Where it went'));
    expect(text, contains('Patterns'));
    expect(text, startsWith('Spending review'));
  });
  // "top 3 categories" lands on the topCategory metric, and a one-line answer
  // was not an answer to it.
  test('top category ranks the runners-up too', () async {
    await add(500, 3, DateTime(2026, 8, 5));
    await add(300, 2, DateTime(2026, 8, 6));
    await add(100, 1, DateTime(2026, 8, 7));

    final answer = await service.buildSummary(
      request: AiSummaryRequest(
        metric: AiSummaryMetric.topCategory,
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 20),
      ),
      categories: categories,
      currencySymbol: r'$',
      currencyCode: 'USD',
    );

    expect(answer, contains('Dining Out'));
    expect(answer, contains('House Rent'));
    expect(answer, contains('House Loan'));
  });

}
