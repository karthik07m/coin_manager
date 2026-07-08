import 'dart:math';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/account.dart';
import '../models/ai_intent.dart';
import '../models/ai_message.dart';
import '../models/category.dart';
import '../providers/transaction_provider.dart';
import '../services/ai_assistant_service.dart';
import '../services/ai_local_parser.dart';
import '../services/ai_summary_service.dart';
import '../utilities/functions.dart';

class AiAssistantProvider extends ChangeNotifier {
  final AiAssistantService _assistantService;
  final AiSummaryService _summaryService;
  final AiLocalParser _localParser;
  final Random _random = Random();

  AiAssistantProvider({
    AiAssistantService? assistantService,
    AiSummaryService? summaryService,
    AiLocalParser? localParser,
  })  : _assistantService = assistantService ?? AiAssistantService(),
        _summaryService = summaryService ?? AiSummaryService(),
        _localParser = localParser ?? AiLocalParser();

  final List<AiAssistantMessage> _messages = [];
  AiTransactionDraft? _pendingDraft;
  bool _isLoading = false;

  List<AiAssistantMessage> get messages => List.unmodifiable(_messages);
  AiTransactionDraft? get pendingDraft => _pendingDraft;
  bool get isLoading => _isLoading;

  static const _summarySuggestions = [
    'Top category this month',
    'What is my income this month?',
    'Net balance this month',
    'Show my upcoming recurring payments',
  ];

  static const _afterSaveSuggestions = [
    'How much did I spend this month?',
    'How much did I spend this week?',
    'Top category this month',
  ];

  Future<void> submitMessage({
    required String message,
    required bool aiEnabled,
    required String functionUrl,
    required String currencySymbol,
    required String currencyCode,
    required List<Category> categories,
    required List<Account> accounts,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _messages.add(AiAssistantMessage.user(trimmed));
    _isLoading = true;
    notifyListeners();

    try {
      // On-device parsing first: instant, offline, and doesn't need any
      // AI setup. The remote AI is only consulted for messages the local
      // parser can't confidently understand.
      AiIntent? intent = _localParser.tryParse(
        message: trimmed,
        categories: categories,
      );

      if (intent == null) {
        if (aiEnabled && functionUrl.trim().isNotEmpty) {
          intent = await _assistantService.parseMessage(
            functionUrl: functionUrl,
            message: trimmed,
            currencyCode: currencyCode,
            currencySymbol: currencySymbol,
            categories: categories,
            accounts: accounts,
          );
        } else {
          _messages.add(
            AiAssistantMessage.assistant(
              "🤔 I didn't quite catch that. Try one of these:\n\n"
              '•  "Add expense 200 coffee"\n'
              '•  "Spent 50 on groceries yesterday"\n'
              '•  "How much did I spend this week?"\n'
              '•  "Top category this month"',
              suggestions: const [
                'How much did I spend this month?',
                'Top category this month',
              ],
            ),
          );
          return;
        }
      }

      await _handleIntent(
        intent,
        categories: categories,
        accounts: accounts,
        currencySymbol: currencySymbol,
        currencyCode: currencyCode,
      );
    } catch (error) {
      _messages.add(
        AiAssistantMessage.assistant(
          error is AiAssistantException
              ? error.message
              : '😅 AI is unavailable right now, but quick commands like '
                  '"Add expense 200 coffee" always work — no internet needed.',
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _handleIntent(
    AiIntent intent, {
    required List<Category> categories,
    required List<Account> accounts,
    required String currencySymbol,
    required String currencyCode,
  }) async {
    switch (intent.type) {
      case AiIntentType.addTransaction:
        final draft = intent.transaction;
        if (draft == null) {
          _messages.add(
              AiAssistantMessage.assistant(AiIntent.unsupported().message));
          return;
        }

        final resolvedDraft = draft.withFallbacks(
          categoryId: _fallbackCategoryId(categories, draft.isExpense),
          accountId: _fallbackAccountId(accounts),
        );
        _pendingDraft = resolvedDraft;
        _messages.add(
          AiAssistantMessage.assistant(
            _draftIntroFor(resolvedDraft, currencySymbol, currencyCode),
            transactionDraft: resolvedDraft,
          ),
        );
        break;
      case AiIntentType.summaryRequest:
        final request = intent.summaryRequest;
        if (request == null) {
          _messages.add(
              AiAssistantMessage.assistant(AiIntent.unsupported().message));
          return;
        }

        final summary = await _summaryService.buildSummary(
          request: request,
          categories: categories,
          currencySymbol: currencySymbol,
          currencyCode: currencyCode,
        );
        _messages.add(AiAssistantMessage.assistant(
          summary,
          suggestions: _followUpsFor(request.metric),
        ));
        break;
      case AiIntentType.unsupported:
        _messages.add(AiAssistantMessage.assistant(intent.message));
        break;
    }
  }

  Future<void> confirmPendingDraft(
    TransactionProvider provider, {
    String currencySymbol = '',
    String currencyCode = '',
  }) async {
    final draft = _pendingDraft;
    if (draft == null) return;

    await provider.addTransaction(draft.toTransaction());
    _pendingDraft = null;
    _messages.add(
      AiAssistantMessage.assistant(
        _confirmationFor(draft, currencySymbol, currencyCode),
        suggestions: _afterSaveSuggestions,
      ),
    );
    notifyListeners();
  }

  void cancelPendingDraft() {
    if (_pendingDraft == null) return;
    _pendingDraft = null;
    _messages.add(
      AiAssistantMessage.assistant('No problem — draft discarded. 🗑️'),
    );
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _pendingDraft = null;
    notifyListeners();
  }

  void updatePendingCategory(int categoryId) {
    final draft = _pendingDraft;
    if (draft == null) return;
    _pendingDraft = draft.copyWith(
      categoryId: categoryId,
      needsCategoryReview: false,
    );
    notifyListeners();
  }

  void updatePendingAccount(int accountId) {
    final draft = _pendingDraft;
    if (draft == null) return;
    _pendingDraft = draft.copyWith(
      accountId: accountId,
      needsAccountReview: false,
    );
    notifyListeners();
  }

  void updatePendingTitle(String title) {
    final draft = _pendingDraft;
    final trimmed = title.trim();
    if (draft == null || trimmed.isEmpty) return;
    _pendingDraft = draft.copyWith(title: trimmed);
    notifyListeners();
  }

  void updatePendingAmount(double amount) {
    final draft = _pendingDraft;
    if (draft == null || amount <= 0) return;
    _pendingDraft = draft.copyWith(amount: amount);
    notifyListeners();
  }

  void updatePendingDate(DateTime date) {
    final draft = _pendingDraft;
    if (draft == null) return;
    _pendingDraft = draft.copyWith(date: date);
    notifyListeners();
  }

  String _draftIntroFor(
    AiTransactionDraft draft,
    String currencySymbol,
    String currencyCode,
  ) {
    final money = _money(draft.amount, currencySymbol, currencyCode);
    final intros = draft.isExpense
        ? [
            'Got it! $money for ${draft.title} — review and save. 👇',
            'One sec... $money on ${draft.title}? Check the details below. 👇',
            'Here\'s your ${draft.title} expense ($money) — look good?',
          ]
        : [
            'Nice! 🎉 $money coming in from ${draft.title} — review below.',
            'Cha-ching! 💰 $money from ${draft.title} — check and save.',
          ];
    return intros[_random.nextInt(intros.length)];
  }

  String _confirmationFor(
    AiTransactionDraft draft,
    String currencySymbol,
    String currencyCode,
  ) {
    final money = _money(draft.amount, currencySymbol, currencyCode);
    final confirmations = draft.isExpense
        ? [
            '💸 Logged! ${draft.title} — $money.',
            '✅ Saved ${draft.title} ($money). Anything else?',
            '📝 ${draft.title} for $money is in the books!',
            '✅ Done! $money on ${draft.title}, tracked.',
          ]
        : [
            '🎉 Sweet! ${draft.title} +$money added.',
            '💰 Income logged: ${draft.title} — $money.',
            '✅ Nice one! $money from ${draft.title}, saved.',
          ];
    return confirmations[_random.nextInt(confirmations.length)];
  }

  List<String> _followUpsFor(AiSummaryMetric metric) {
    switch (metric) {
      case AiSummaryMetric.totalSpending:
      case AiSummaryMetric.categorySpending:
        return const [
          'Top category this month',
          'Net balance this month',
          'How much did I spend last month?',
        ];
      case AiSummaryMetric.totalIncome:
        return const [
          'How much did I spend this month?',
          'Net balance this month',
        ];
      case AiSummaryMetric.netBalance:
        return const [
          'How much did I spend this month?',
          'Top category this month',
        ];
      case AiSummaryMetric.topCategory:
        return const [
          'How much did I spend this month?',
          'Net balance this month',
        ];
      case AiSummaryMetric.upcomingRecurring:
        return _summarySuggestions
            .where((s) => !s.contains('upcoming'))
            .toList();
    }
  }

  String _money(double amount, String symbol, String code) {
    return UtilityFunction.addCommaWithSign(
      amount,
      currencySymbol: symbol,
      currencyCode: code,
    );
  }

  int _fallbackCategoryId(List<Category> categories, bool isExpense) {
    for (final category in categories) {
      if (category.id != null && category.isExpense == isExpense) {
        return category.id!;
      }
    }

    for (final category in categories) {
      if (category.id != null) return category.id!;
    }

    return isExpense ? 1 : 9;
  }

  int _fallbackAccountId(List<Account> accounts) {
    for (final account in accounts) {
      if (account.id != null && account.isDefault) return account.id!;
    }

    for (final account in accounts) {
      if (account.id != null) return account.id!;
    }

    return 1;
  }
}
