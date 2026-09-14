import 'package:coin_manager/models/account.dart';
import 'package:coin_manager/models/ai_intent.dart';
import 'package:coin_manager/models/ai_message.dart';
import 'package:coin_manager/models/category.dart';
import 'package:coin_manager/models/transaction.dart';
import 'package:coin_manager/providers/ai_assistant_provider.dart';
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
      message: 'Add lunch',
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
      message: 'Add lunch',
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
