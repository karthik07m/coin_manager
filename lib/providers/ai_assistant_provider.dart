import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../db/transaction_db_helper.dart';
import '../models/account.dart';
import '../models/ai_intent.dart';
import '../models/ai_message.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../services/ai_assistant_service.dart';
import '../services/ai_local_parser.dart';
import '../services/ai_summary_service.dart';
import '../utilities/budget_period.dart';
import '../utilities/functions.dart';

class AiAssistantProvider extends ChangeNotifier {
  final AiAssistantService _assistantService;
  final AiSummaryService _summaryService;
  final AiLocalParser _localParser;

  /// Category last used for an identical title, so "coffee 200" lands in
  /// whatever the user filed coffee under before. Injected so tests run
  /// without a database.
  final Future<int?> Function(String title, bool isExpense) _lastCategoryFor;

  /// Transactions whose title or category matches [term] in the given window,
  /// newest first. Injected so tests run without a database.
  final Future<List<Transaction>> Function(
      String term, DateTime start, DateTime end) _findTransactions;

  AiAssistantProvider({
    AiAssistantService? assistantService,
    AiSummaryService? summaryService,
    AiLocalParser? localParser,
    Future<int?> Function(String title, bool isExpense)? lastCategoryFor,
    Future<List<Transaction>> Function(String, DateTime, DateTime)?
        findTransactions,
  })  : _assistantService = assistantService ?? AiAssistantService(),
        _summaryService = summaryService ?? AiSummaryService(),
        _localParser = localParser ?? AiLocalParser(),
        _lastCategoryFor = lastCategoryFor ??
            ((title, isExpense) =>
                TransactionDBHelper().getLastCategoryIdForTitle(title, isExpense)),
        _findTransactions = findTransactions ?? _defaultFinder;

  static Future<List<Transaction>> _defaultFinder(
      String term, DateTime start, DateTime end) async {
    final rows = await TransactionDBHelper()
        .getTransactionsByType(startDate: start, endDate: end);
    final needle = term.toLowerCase();
    final matches = rows
        .where((t) => !t.isTransfer && t.title.toLowerCase().contains(needle))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return matches;
  }

  final List<AiAssistantMessage> _messages = [];
  AiTransactionDraft? _pendingDraft;
  AiTransferDraft? _pendingTransfer;
  ({Transaction target, double? newAmount, bool isDelete})? _pendingEdit;
  bool _isLoading = false;

  /// The last summary asked for, so "and last month?" can re-ask it.
  AiSummaryRequest? _lastSummary;

  /// Id of the transaction the chat saved most recently, for "undo".
  String? _lastSavedId;
  String? _lastSavedLabel;

  List<AiAssistantMessage> get messages => List.unmodifiable(_messages);
  AiTransactionDraft? get pendingDraft => _pendingDraft;
  AiTransferDraft? get pendingTransfer => _pendingTransfer;
  bool get hasPendingEdit => _pendingEdit != null;

  /// Cloud AI requests left this month, once the cloud has answered at least
  /// once. Null means "not known yet", not "none left".
  int? get creditsRemaining => _assistantService.lastCreditsRemaining;
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
    'discard',
  ];

  static const _helpText = 'Here\'s what I can do:\n\n'
      '**Log money**\n'
      '•  "coffee 150" or "spent 2k on groceries yesterday"\n'
      '•  "got salary 50000" · "paid 300 uber from cash"\n'
      '•  "transfer 500 from chase to cash"\n\n'
      '**Answer questions**\n'
      '•  "how much did I spend this week?"\n'
      '•  "top category last month" · "biggest expense"\n'
      '•  "find netflix" · "when did I last pay rent?"\n'
      '•  "what\'s my net worth?" · "how\'s my budget?"\n\n'
      '**Advise**\n'
      '•  "my spending habits" · "how can I save money?"\n'
      '•  "compare this month vs last"\n\n'
      'I remember context: after a question, just say "and last month?". '
      'Made a mistake? Say "undo".';

  static const _summarySuggestions = [
    'My spending habits',
    'Top category this month',
    'What is my income this month?',
    'Net balance this month',
    'Show my upcoming recurring payments',
  ];

  static const _afterSaveSuggestions = [
    'How much did I spend today?',
    'How\'s my budget?',
    'Undo',
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
      // An edit or delete is waiting on a yes/no. It touches money already in
      // the ledger, so it is resolved before anything else is parsed.
      if (_pendingEdit != null) {
        final handled =
            await _resolvePendingEdit(trimmed.toLowerCase(), transactionProvider);
        if (handled) return;
      }

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

      // Likewise a draft: "yes" / "save" saves it, "no" discards it.
      if (_pendingDraft != null && transactionProvider != null) {
        final handled = await _resolvePendingDraft(
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
        previous: _lastSummary,
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
              _didNotCatch(trimmed),
              suggestions: const [
                'Help',
                'What\'s my net worth?',
                'My spending habits',
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
    try {
      await transactionProvider.addTransfer(
        fromAccountId: transfer.fromAccountId,
        toAccountId: transfer.toAccountId,
        amount: transfer.amount,
        date: DateTime.now(),
      );
    } on TransferCurrencyMismatch catch (e) {
      _messages.add(AiAssistantMessage.assistant(
        '🚫 ${transfer.fromName} is in ${e.fromCurrency} and '
        '${transfer.toName} is in ${e.toCurrency}. A transfer moves one '
        'amount, so both accounts need the same currency. Add it as an '
        'expense on ${transfer.fromName} and an income on '
        '${transfer.toName} instead.',
      ));
      return true;
    }
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

  /// Handles yes/no replies while a transaction draft is awaiting review.
  /// Anything else is treated as a new message and the draft stays open.
  Future<bool> _resolvePendingDraft(
    String lower,
    TransactionProvider transactionProvider,
    String currencySymbol,
    String currencyCode,
  ) async {
    final words = lower.replaceAll(RegExp(r'[^a-z\s]'), '').trim();
    final cancelled = _cancelWords.contains(words);
    final confirmed = !cancelled &&
        (_confirmWords.contains(words) ||
            const ['save', 'save it', 'add it', 'log it', 'looks good', 'correct']
                .contains(words));
    if (cancelled) {
      cancelPendingDraft();
      return true;
    }
    if (!confirmed) return false;
    await confirmPendingDraft(
      transactionProvider,
      currencySymbol: currencySymbol,
      currencyCode: currencyCode,
    );
    return true;
  }

  /// A fallback that reflects what the message looked like, instead of the
  /// same six examples every time.
  String _didNotCatch(String message) {
    final hasNumber = RegExp(r'\d').hasMatch(message);
    if (hasNumber) {
      return '🤔 I saw a number but couldn\'t tell what to do with it. To '
          'log it, try:\n\n'
          '•  "coffee 150"\n'
          '•  "spent 500 on groceries yesterday"\n'
          '•  "got salary 50000"\n\n'
          'Or say "help" to see everything I understand.';
    }
    return '🤔 I didn\'t quite catch that. Try one of these:\n\n'
        '•  "How much did I spend this week?"\n'
        '•  "Find netflix"\n'
        '•  "What\'s my net worth?"\n'
        '•  "My spending habits"\n\n'
        'Or say "help" to see everything I understand.';
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
      case AiIntentType.help:
        _messages.add(AiAssistantMessage.assistant(
          _helpText,
          suggestions: const [
            'How much did I spend this week?',
            'What\'s my net worth?',
            'My spending habits',
          ],
        ));
        return;
      case AiIntentType.smallTalk:
        _messages.add(AiAssistantMessage.assistant(
          _smallTalkReply(intent.message),
          suggestions: const [
            'How\'s my budget?',
            'How much did I spend today?',
            'Help',
          ],
        ));
        return;
      case AiIntentType.calculation:
        _messages.add(AiAssistantMessage.assistant(
          '🧮 = ${intent.message}',
          suggestions: [
            'Add expense ${intent.message}',
            'Add income ${intent.message}',
          ],
        ));
        return;
      case AiIntentType.undo:
        await _undoLastSave(transactionProvider);
        return;
      case AiIntentType.editTransaction:
        await _handleEdit(
          intent.edit!,
          transactionProvider,
          currencySymbol,
          currencyCode,
        );
        return;
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

        var learned = draft;
        if (draft.categoryId == null) {
          try {
            final remembered =
                await _lastCategoryFor(draft.title, draft.isExpense);
            if (remembered != null &&
                categories.any((c) => c.id == remembered)) {
              learned = draft.copyWith(
                categoryId: remembered,
                needsCategoryReview: false,
              );
            }
          } catch (_) {
            // History is a convenience; the fallback category still works.
          }
        }
        final resolvedDraft = learned.withFallbacks(
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
        _lastSummary = request;
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

  /// Finds what the user pointed at and asks before changing it. Nothing is
  /// written here — a wrong guess about which transaction they meant would
  /// silently rewrite real money, so every path ends in a confirmation.
  Future<void> _handleEdit(
    AiEditRequest request,
    TransactionProvider? provider,
    String currencySymbol,
    String currencyCode,
  ) async {
    final verb = request.isDelete ? 'delete' : 'change';

    if (provider == null) {
      _messages.add(AiAssistantMessage.assistant(
          '😅 I could not reach your transactions just now — please try again.'));
      return;
    }

    Transaction? target;
    if (request.term == null) {
      // "change that" / "delete that" means the one I just saved.
      final id = _lastSavedId;
      if (id == null) {
        _messages.add(AiAssistantMessage.assistant(
          'I have not saved anything in this chat yet, so I do not know what '
          '"that" is. Name it instead — for example "$verb netflix".',
        ));
        return;
      }
      target = await _findById(provider, id);
      if (target == null) {
        _messages.add(AiAssistantMessage.assistant(
            'That one is not in your ledger any more — nothing to $verb.'));
        _lastSavedId = null;
        return;
      }
    } else {
      final matches = await _findTransactions(
        request.term!,
        request.start ?? DateTime(2000),
        request.end ?? DateTime.now(),
      );
      if (matches.isEmpty) {
        _messages.add(AiAssistantMessage.assistant(
          '🔍 I could not find a transaction matching "${request.term}". '
          'Try the words as they appear in the title.',
        ));
        return;
      }
      if (matches.length > 1) {
        // Picking one for them would be guessing with their money.
        final lines = matches.take(5).map((t) =>
            '•  ${UtilityFunction.formateDate(t.date)} · ${t.title} · '
            '${_money(t.amount, currencySymbol, currencyCode)}');
        _messages.add(AiAssistantMessage.assistant(
          '🔍 ${matches.length} transactions match "${request.term}":\n\n'
          '${lines.join('\n')}\n\n'
          'Which one? Add the date — for example "$verb '
          '${request.term} on ${UtilityFunction.formateDate(matches.first.date)}".',
        ));
        return;
      }
      target = matches.first;
    }

    _pendingEdit = (
      target: target,
      newAmount: request.newAmount,
      isDelete: request.isDelete,
    );

    final money = _money(target.amount, currencySymbol, currencyCode);
    final when = UtilityFunction.formateDate(target.date);
    _messages.add(AiAssistantMessage.assistant(
      request.isDelete
          ? '🗑️ Delete **${target.title}** — $money on $when?\n\n'
              'Reply "confirm" to remove it or "cancel" to keep it.'
          : '✏️ Change **${target.title}** ($when) from $money to '
              '${_money(request.newAmount!, currencySymbol, currencyCode)}?'
              '\n\nReply "confirm" to apply it or "cancel" to leave it alone.',
      suggestions: const ['Confirm', 'Cancel'],
    ));
  }

  Future<Transaction?> _findById(
      TransactionProvider provider, String id) async {
    for (final t in provider.transactions) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Applies an edit or delete once the user has said yes. Returns true when
  /// the message was consumed.
  Future<bool> _resolvePendingEdit(
    String lower,
    TransactionProvider? provider,
  ) async {
    final words = lower.replaceAll(RegExp(r'[^a-z\s]'), '').trim();
    final cancelled = _cancelWords.contains(words);
    final confirmed = !cancelled &&
        (_confirmWords.contains(words) ||
            const ['do it', 'delete it', 'change it', 'go ahead']
                .contains(words));

    if (cancelled) {
      final wasDelete = _pendingEdit!.isDelete;
      _pendingEdit = null;
      _messages.add(AiAssistantMessage.assistant(
          wasDelete ? 'Left it alone. 👍' : 'No change made. 👍'));
      return true;
    }
    if (!confirmed) return false; // treat it as a brand-new message

    final pending = _pendingEdit!;
    _pendingEdit = null;
    if (provider == null) {
      _messages.add(AiAssistantMessage.assistant(
          '😅 I could not reach your transactions just now — please try again.'));
      return true;
    }

    if (pending.isDelete) {
      await provider.deleteTransaction(pending.target.id);
      if (_lastSavedId == pending.target.id) _lastSavedId = null;
      _messages.add(AiAssistantMessage.assistant(
        '🗑️ Deleted "${pending.target.title}".',
        suggestions: const ['How much did I spend this month?'],
      ));
      return true;
    }

    pending.target.amount = pending.newAmount!;
    await provider.updateTransaction(pending.target);
    _messages.add(AiAssistantMessage.assistant(
      '✏️ Updated "${pending.target.title}".',
      suggestions: const ['How much did I spend this month?'],
    ));
    return true;
  }

  Future<void> confirmPendingDraft(
    TransactionProvider provider, {
    String currencySymbol = '',
    String currencyCode = '',
  }) async {
    final draft = _pendingDraft;
    if (draft == null) return;

    final transaction = draft.toTransaction();
    await provider.addTransaction(transaction);
    _pendingDraft = null;
    _lastSavedId = transaction.id;
    _lastSavedLabel = draft.title;
    _messages.add(
      AiAssistantMessage.assistant(
        _confirmationFor(draft, currencySymbol, currencyCode),
        suggestions: _afterSaveSuggestions,
      ),
    );
    notifyListeners();
  }

  Future<void> _undoLastSave(TransactionProvider? provider) async {
    final id = _lastSavedId;
    if (id == null || provider == null) {
      _messages.add(AiAssistantMessage.assistant(
        'Nothing to undo — I haven\'t saved anything in this chat yet.',
      ));
      return;
    }
    await provider.deleteTransaction(id);
    _lastSavedId = null;
    _messages.add(AiAssistantMessage.assistant(
      '↩️ Removed "$_lastSavedLabel". As if it never happened.',
      suggestions: const ['How much did I spend today?'],
    ));
    _lastSavedLabel = null;
  }

  String _smallTalkReply(String greeting) {
    if (greeting.startsWith('thank')) {
      return 'Anytime! 🙌 Anything else you want to check?';
    }
    if (const ['ok', 'okay', 'cool', 'nice', 'great'].contains(greeting)) {
      return '👍 Here whenever you need me.';
    }
    final hour = DateTime.now().hour;
    final time = hour < 12
        ? 'morning'
        : hour < 17
            ? 'afternoon'
            : 'evening';
    return 'Hey! 👋 Good $time. Log something like "coffee 150", or ask me '
        'how your month is going.';
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
    _pendingEdit = null;
    _lastSummary = null;
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
    return draft.isExpense
        ? '$money for ${draft.title} — check it and save. 👇'
        : '$money in from ${draft.title} — check it and save. 👇';
  }

  /// One steady line, not a rotating set of exclamations. "Cha-ching!" is
  /// charming for a week and wearing by the second month, and a confirmation
  /// is something the user reads every single time they log anything.
  String _confirmationFor(
    AiTransactionDraft draft,
    String currencySymbol,
    String currencyCode,
  ) {
    final money = _money(draft.amount, currencySymbol, currencyCode);
    return draft.isExpense
        ? '✅ Saved ${draft.title} — $money.'
        : '✅ Saved ${draft.title} — +$money.';
  }

  /// Suggestion chip that opens the Charts tab instead of sending a prompt.
  static const openChartsChip = 'Open Charts';

  List<String> _followUpsFor(AiSummaryMetric metric) {
    return [..._promptsFor(metric), openChartsChip];
  }

  List<String> _promptsFor(AiSummaryMetric metric) {
    switch (metric) {
      case AiSummaryMetric.monthComparison:
      case AiSummaryMetric.totalSpending:
      case AiSummaryMetric.categorySpending:
        return const [
          'My spending habits',
          'Top category this month',
          'How much did I spend last month?',
        ];
      case AiSummaryMetric.spendingHabits:
        return const [
          'Top category this month',
          'Net balance this month',
          'My spending habits last month',
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
      case AiSummaryMetric.largestExpense:
      case AiSummaryMetric.recentTransactions:
      case AiSummaryMetric.searchTransactions:
        return const [
          'And last month?',
          'How much did I spend this month?',
          'Top category this month',
        ];
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
    final now = DateTime.now();
    final daysLeft = BudgetPeriod.daysRemaining(now);
    final left = total - used;
    final perDay = daysLeft > 0 ? left / daysLeft : left;
    // Pace: are they ahead of or behind an even spread of the budget?
    final daysInMonth = BudgetPeriod.daysInMonth(now);
    final elapsed = (BudgetPeriod.daysElapsed(now) + 1).clamp(1, daysInMonth);
    final expected = total * elapsed / daysInMonth;
    final pace = used <= expected
        ? 'You\'re on track — ${money(expected - used)} under an even pace.'
        : 'Slightly ahead of pace — ${money(used - expected)} over an even '
            'spread.';
    return '📊 Budget: ${money(used)} of ${money(total)} used ($pct%).\n'
        '${money(left)} left · about ${money(perDay)} a day for the next '
        '$daysLeft day${daysLeft == 1 ? '' : 's'}.\n\n$pace';
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
