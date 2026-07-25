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
  AiTransferDraft? _pendingTransfer;
  bool _isLoading = false;

  List<AiAssistantMessage> get messages => List.unmodifiable(_messages);
  AiTransactionDraft? get pendingDraft => _pendingDraft;
  AiTransferDraft? get pendingTransfer => _pendingTransfer;
  bool get isLoading => _isLoading;

  static const _confirmWords = [
    'yes',
    'confirm',
    'do it',
    'go ahead',
    'sure',
    'ok',
    'okay',
    'yep',
    'yeah',
  ];
  static const _cancelWords = [
    'no',
    'cancel',
    'stop',
    'nevermind',
    'never mind',
    'don\'t',
    'dont',
  ];

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
    TransactionProvider? transactionProvider,
    double? budgetTotal,
    double? budgetSpent,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _messages.add(AiAssistantMessage.user(trimmed));
    _isLoading = true;
    notifyListeners();

    try {
      // A transfer is waiting on a yes/no — resolve that before parsing
      // anything new.
      if (_pendingTransfer != null) {
        final handled = await _resolvePendingTransfer(
          trimmed.toLowerCase(),
          transactionProvider,
          currencySymbol,
          currencyCode,
        );
        if (handled) return;
      }

      // On-device parsing first: instant, offline, and doesn't need any
      // AI setup. The remote AI is only consulted for messages the local
      // parser can't confidently understand.
      AiIntent? intent = _localParser.tryParse(
        message: trimmed,
        categories: categories,
        accounts: accounts,
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
              '•  "Transfer 200 from Chase to Cash"\n'
              '•  "What\'s my net worth?"\n'
              '•  "How\'s my budget?"\n'
              '•  "How much did I spend this week?"',
              suggestions: const [
                'What\'s my net worth?',
                'How\'s my budget?',
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
        transactionProvider: transactionProvider,
        budgetTotal: budgetTotal,
        budgetSpent: budgetSpent,
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

  /// Handles yes/no replies while a transfer is awaiting confirmation.
  /// Returns true when the message was consumed.
  Future<bool> _resolvePendingTransfer(
    String lower,
    TransactionProvider? transactionProvider,
    String currencySymbol,
    String currencyCode,
  ) async {
    final transfer = _pendingTransfer!;
    final confirmed = _confirmWords.any(lower.contains) &&
        !_cancelWords.any(lower.contains);
    final cancelled = _cancelWords.any(lower.contains);

    if (cancelled) {
      _pendingTransfer = null;
      _messages
          .add(AiAssistantMessage.assistant('Transfer cancelled. 🗑️'));
      return true;
    }
    if (!confirmed) return false; // treat as a brand-new message

    _pendingTransfer = null;
    if (transactionProvider == null) {
      _messages.add(AiAssistantMessage.assistant(
          '😅 I couldn\'t reach your accounts just now — please try again.'));
      return true;
    }
    await transactionProvider.addTransfer(
      fromAccountId: transfer.fromAccountId,
      toAccountId: transfer.toAccountId,
      amount: transfer.amount,
      date: DateTime.now(),
    );
    final money = _money(transfer.amount, currencySymbol, currencyCode);
    _messages.add(AiAssistantMessage.assistant(
      '✅ Transferred $money from ${transfer.fromName} to ${transfer.toName}.',
      suggestions: const [
        'What\'s my net worth?',
        'How\'s my budget?',
      ],
    ));
    return true;
  }

  Future<void> _handleIntent(
    AiIntent intent, {
    required List<Category> categories,
    required List<Account> accounts,
    required String currencySymbol,
    required String currencyCode,
    TransactionProvider? transactionProvider,
    double? budgetTotal,
    double? budgetSpent,
  }) async {
    switch (intent.type) {
      case AiIntentType.transfer:
        final transfer = intent.transfer;
        if (transfer == null) {
          _messages.add(
              AiAssistantMessage.assistant(AiIntent.unsupported().message));
          return;
        }
        _pendingTransfer = transfer;
        final money = _money(transfer.amount, currencySymbol, currencyCode);
        _messages.add(AiAssistantMessage.assistant(
          '🔁 Transfer $money from ${transfer.fromName} to '
          '${transfer.toName}?\n\nReply "confirm" to move the money or '
          '"cancel" to discard.',
          suggestions: const ['Confirm', 'Cancel'],
        ));
        return;
      case AiIntentType.accountQuery:
        _messages.add(AiAssistantMessage.assistant(
          _accountAnswer(
              intent.accountQuery, accounts, currencySymbol, currencyCode),
          suggestions: const [
            'How\'s my budget?',
            'How much did I spend this month?',
          ],
        ));
        return;
      case AiIntentType.budgetQuery:
        _messages.add(AiAssistantMessage.assistant(
          _budgetAnswer(
              budgetTotal, budgetSpent, currencySymbol, currencyCode),
          suggestions: const [
            'Top category this month',
            'What\'s my net worth?',
          ],
        ));
        return;
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
          amountOf: transactionProvider?.baseAmount,
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
    _pendingTransfer = null;
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

  /// Answers "what's my net worth" / "chase balance" from loaded accounts.
  String _accountAnswer(
    AiAccountQuery? query,
    List<Account> accounts,
    String symbol,
    String code,
  ) {
    if (accounts.isEmpty) {
      return 'You don\'t have any accounts yet — add one in Manage Accounts.';
    }

    String money(double v) => _money(v, symbol, code);

    if (query?.accountId != null) {
      final acc = accounts.firstWhere(
        (a) => a.id == query!.accountId,
        orElse: () => accounts.first,
      );
      if (acc.isLiability) {
        final available = acc.availableCredit;
        final owed = money(acc.currentBalance);
        return available != null
            ? '💳 ${acc.name}: $owed owed · ${money(available)} '
                'available of ${money(acc.creditLimit!)}.'
            : '💳 ${acc.name}: $owed owed.';
      }
      return '🏦 ${acc.name} balance: ${money(acc.currentBalance)}.';
    }

    double assets = 0, liabilities = 0;
    final lines = <String>[];
    for (final a in accounts) {
      if (a.isLiability) {
        liabilities += a.currentBalance;
        lines.add('•  ${a.name}: ${money(a.currentBalance)} owed');
      } else {
        assets += a.currentBalance;
        lines.add('•  ${a.name}: ${money(a.currentBalance)}');
      }
    }
    final net = assets - liabilities;
    return '💰 Net worth: ${money(net)}\n'
        '(assets ${money(assets)} − debts ${money(liabilities)})\n\n'
        '${lines.join('\n')}';
  }

  /// Answers "how's my budget" from this month's budget vs spending.
  String _budgetAnswer(
    double? total,
    double? spent,
    String symbol,
    String code,
  ) {
    if (total == null || total <= 0) {
      return 'You haven\'t set a monthly budget yet — set one in the Budget '
          'tab and I\'ll track it for you. 📊';
    }
    final used = spent ?? 0;
    final pct = (used / total * 100).round();
    String money(double v) => _money(v, symbol, code);
    if (used > total) {
      return '🚨 You\'re over budget: spent ${money(used)} of '
          '${money(total)} ($pct%). Over by ${money(used - total)}.';
    }
    return '📊 Budget check: ${money(used)} spent of ${money(total)} '
        '($pct%). ${money(total - used)} left this month.';
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
