import 'package:coin_manager/models/account.dart';
import 'package:coin_manager/models/ai_intent.dart';
import 'package:coin_manager/models/ai_message.dart';
import 'package:coin_manager/models/category.dart';
import 'package:coin_manager/models/transaction.dart';
import 'package:coin_manager/providers/ai_assistant_provider.dart';
import 'package:coin_manager/providers/transaction_provider.dart';
import 'package:coin_manager/services/ai_assistant_service.dart';
import 'package:coin_manager/services/ai_summary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final categories = [
    Category(id: 1, name: 'Food', icon: 'food.png', isExpense: true),
  ];
  final accounts = [
    Account(
      id: 1,
      name: 'Cash',
      icon: 'wallet',
      color: '#4CAF50',
      isDefault: true,
      createdOn: DateTime(2026),
      modifiedOn: DateTime(2026),
    ),
  ];

  test('adds pending draft for add transaction intent', () async {
    final provider = AiAssistantProvider(
      assistantService: _FakeAssistantService(
        AiIntent(
          type: AiIntentType.addTransaction,
          confidence: 0.9,
          message: 'Review this transaction.',
          transaction: AiTransactionDraft(
            title: 'Lunch',
            amount: 12,
            isExpense: true,
            date: DateTime(2026, 6, 16),
          ),
        ),
      ),
    );

    await provider.submitMessage(
      message: 'put down twelve dollars for lunch yesterday',
      aiEnabled: true,
      functionUrl: 'https://example.supabase.co/functions/v1/finance-ai',
      currencySymbol: r'$',
      currencyCode: 'USD',
      categories: categories,
      accounts: accounts,
    );

    expect(provider.pendingDraft?.categoryId, 1);
    expect(provider.pendingDraft?.accountId, 1);
    expect(provider.messages.last.transactionDraft?.title, 'Lunch');
  });

  test('offers help for unparseable message when AI is off', () async {
    final provider = AiAssistantProvider(
      assistantService: _FakeAssistantService(AiIntent.unsupported()),
    );

    await provider.submitMessage(
      message: 'tell me a joke',
      aiEnabled: false,
      functionUrl: '',
      currencySymbol: r'$',
      currencyCode: 'USD',
      categories: categories,
      accounts: accounts,
    );

    expect(provider.messages.last.role, AiMessageRole.assistant);
    expect(provider.messages.last.text, contains('help'));
    expect(provider.pendingDraft, isNull);
  });

  test('a bare period re-asks the previous summary', () async {
    final summaryService = _FakeSummaryService();
    final provider = AiAssistantProvider(
      assistantService: _FakeAssistantService(AiIntent.unsupported()),
      summaryService: summaryService,
      lastCategoryFor: (_, __) async => null,
    );
    Future<void> ask(String text) => provider.submitMessage(
          message: text,
          aiEnabled: false,
          functionUrl: '',
          currencySymbol: r'$',
          currencyCode: 'USD',
          categories: categories,
          accounts: accounts,
        );

    await ask('how much did I spend this month?');
    expect(summaryService.lastRequest?.metric, AiSummaryMetric.totalSpending);

    await ask('and last month?');
    final now = DateTime.now();
    expect(summaryService.lastRequest?.metric, AiSummaryMetric.totalSpending);
    expect(summaryService.lastRequest?.startDate,
        DateTime(now.year, now.month - 1, 1));
    expect(provider.messages.last.text, 'Local summary.');
  });

  test('remembers the category last used for a title', () async {
    final provider = AiAssistantProvider(
      assistantService: _FakeAssistantService(AiIntent.unsupported()),
      lastCategoryFor: (title, isExpense) async =>
          title == 'Haircut' && isExpense ? 1 : null,
    );
    await provider.submitMessage(
      message: 'haircut 300',
      aiEnabled: false,
      functionUrl: '',
      currencySymbol: r'$',
      currencyCode: 'USD',
      categories: categories,
      accounts: accounts,
    );
    expect(provider.pendingDraft?.categoryId, 1);
    expect(provider.pendingDraft?.needsCategoryReview, isFalse);
  });

  test('local quick command works even when AI is off', () async {
    final provider = AiAssistantProvider(
      assistantService: _FakeAssistantService(AiIntent.unsupported()),
    );

    await provider.submitMessage(
      message: 'add expense 200 coffee',
      aiEnabled: false,
      functionUrl: '',
      currencySymbol: r'$',
      currencyCode: 'USD',
      categories: categories,
      accounts: accounts,
    );

    expect(provider.pendingDraft, isNotNull);
    expect(provider.pendingDraft?.amount, 200);
    expect(provider.pendingDraft?.title, 'Coffee');
    expect(provider.pendingDraft?.isExpense, isTrue);
  });

  test('uses local summary service for summary intent', () async {
    final provider = AiAssistantProvider(
      assistantService: _FakeAssistantService(
        AiIntent(
          type: AiIntentType.summaryRequest,
          confidence: 0.8,
          message: 'Checking.',
          summaryRequest: AiSummaryRequest(
            metric: AiSummaryMetric.totalSpending,
            startDate: DateTime(2026, 6, 1),
            endDate: DateTime(2026, 6, 30),
          ),
        ),
      ),
      summaryService: _FakeSummaryService(),
    );

    await provider.submitMessage(
      message: 'How much did I spend?',
      aiEnabled: true,
      functionUrl: 'https://example.supabase.co/functions/v1/finance-ai',
      currencySymbol: r'$',
      currencyCode: 'USD',
      categories: categories,
      accounts: accounts,
    );

    expect(provider.messages.last.text, 'Local summary.');
  });

  // Editing and deleting touch money already in the ledger, so the rule these
  // tests pin down is: never act on the first guess, always confirm.
  group('edit and delete by description', () {
    Transaction row(String id, String title, double amount, DateTime date) =>
        Transaction.createNew(
          id: id,
          title: title,
          amount: amount,
          categoryId: 1,
          accountId: 1,
          date: date,
          isExpense: true,
        );

    AiAssistantProvider build(_FakeTransactions txns, List<Transaction> found) {
      return AiAssistantProvider(
        assistantService: _FakeAssistantService(AiIntent.unsupported()),
        summaryService: _FakeSummaryService(),
        findTransactions: (term, start, end) async => found,
      );
    }

    Future<void> send(AiAssistantProvider p, String message,
        _FakeTransactions txns) {
      return p.submitMessage(
        message: message,
        aiEnabled: false,
        functionUrl: '',
        currencySymbol: r'$',
        currencyCode: 'USD',
        categories: categories,
        accounts: accounts,
        transactionProvider: txns,
      );
    }

    test('one match asks before deleting, and deletes only on confirm',
        () async {
      final hit = row('a', 'Netflix', 649, DateTime(2026, 9, 3));
      final txns = _FakeTransactions([hit]);
      final provider = build(txns, [hit]);

      await send(provider, 'delete netflix', txns);
      expect(txns.deleted, isEmpty, reason: 'must not delete before asking');
      expect(provider.hasPendingEdit, isTrue);
      expect(provider.messages.last.text, contains('Netflix'));

      await send(provider, 'confirm', txns);
      expect(txns.deleted, ['a']);
      expect(provider.hasPendingEdit, isFalse);
    });

    test('cancel leaves the transaction alone', () async {
      final hit = row('a', 'Netflix', 649, DateTime(2026, 9, 3));
      final txns = _FakeTransactions([hit]);
      final provider = build(txns, [hit]);

      await send(provider, 'delete netflix', txns);
      await send(provider, 'cancel', txns);
      expect(txns.deleted, isEmpty);
      expect(provider.hasPendingEdit, isFalse);
    });

    test('several matches list them instead of picking one', () async {
      final a = row('a', 'Netflix', 649, DateTime(2026, 9, 3));
      final b = row('b', 'Netflix', 649, DateTime(2026, 8, 3));
      final txns = _FakeTransactions([a, b]);
      final provider = build(txns, [a, b]);

      await send(provider, 'delete netflix', txns);
      expect(txns.deleted, isEmpty);
      expect(provider.hasPendingEdit, isFalse);
      expect(provider.messages.last.text, contains('2 transactions match'));
    });

    test('no match says so rather than deleting something close', () async {
      final txns = _FakeTransactions([]);
      final provider = build(txns, []);

      await send(provider, 'delete spotify', txns);
      expect(txns.deleted, isEmpty);
      expect(provider.messages.last.text, contains('could not find'));
    });

    test('"change that to 200" with nothing saved yet asks for a name',
        () async {
      final txns = _FakeTransactions([]);
      final provider = build(txns, []);

      await send(provider, 'change that to 200', txns);
      expect(txns.updated, isEmpty);
      expect(provider.messages.last.text, contains('not saved anything'));
    });

    test('an amount change applies only after confirmation', () async {
      final hit = row('a', 'Netflix', 649, DateTime(2026, 9, 3));
      final txns = _FakeTransactions([hit]);
      final provider = build(txns, [hit]);

      await send(provider, 'change netflix to 199', txns);
      expect(txns.updated, isEmpty);
      expect(provider.hasPendingEdit, isTrue);

      await send(provider, 'confirm', txns);
      expect(txns.updated, ['a']);
      expect(hit.amount, 199);
    });
  });
}

class _FakeAssistantService extends AiAssistantService {
  final AiIntent intent;

  _FakeAssistantService(this.intent);

  @override
  Future<AiIntent> parseMessage({
    required String functionUrl,
    required String message,
    required String currencyCode,
    required String currencySymbol,
    required List<Category> categories,
    required List<Account> accounts,
  }) async {
    return intent;
  }
}

class _FakeSummaryService extends AiSummaryService {
  AiSummaryRequest? lastRequest;

  @override
  Future<String> buildSummary({
    required AiSummaryRequest request,
    required List<Category> categories,
    required String currencySymbol,
    required String currencyCode,
    double Function(Transaction)? amountOf,
  }) async {
    lastRequest = request;
    return 'Local summary.';
  }
}

/// Stands in for the real provider so the edit tests never touch a database.
class _FakeTransactions extends TransactionProvider {
  final List<Transaction> _rows;
  final List<String> deleted = [];
  final List<String> updated = [];

  _FakeTransactions(this._rows);

  @override
  List<Transaction> get transactions => _rows;

  @override
  Future<void> deleteTransaction(String id, {bool deleteReceipt = true}) async {
    deleted.add(id);
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    updated.add(transaction.id);
  }
}
