import '../models/ai_intent.dart';
import '../models/category.dart';

/// On-device parser for common finance commands so the chat works instantly,
/// offline, and without a configured AI function URL. Handles structured
/// phrases like "add expense 200 coffee", "spent 50 on groceries yesterday",
/// or "how much did I spend this week?". Returns null when the message is
/// too free-form, letting the caller fall back to the remote AI.
class AiLocalParser {
  static final RegExp _amountPattern = RegExp(
    r'(?:^|[\s₹$€£])(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)(?=\s|$|[.,!?])',
  );

  static const _incomeWords = [
    'income',
    'salary',
    'earned',
    'received',
    'refund',
    'bonus',
    'got paid',
    'cashback',
  ];

  static const _expenseVerbs = [
    'spent',
    'paid',
    'bought',
    'purchase',
    'purchased',
    'expense',
    'add ',
    'log ',
  ];

  static const _questionWords = [
    'how much',
    'how many',
    'what',
    'show',
    'summary',
    'total',
    'give me',
    'tell me',
    'top ',
    'biggest',
    'upcoming',
    'balance',
    '?',
  ];

  AiIntent? tryParse({
    required String message,
    required List<Category> categories,
  }) {
    final text = message.trim().toLowerCase();
    if (text.isEmpty) return null;

    final isQuestion = _questionWords.any(text.contains) &&
        !text.startsWith('add ') &&
        !text.startsWith('log ');
    if (isQuestion) {
      return _parseSummary(text, categories);
    }

    return _parseAddTransaction(text, categories);
  }

  AiIntent? _parseSummary(String text, List<Category> categories) {
    final period = _parsePeriod(text);

    AiSummaryMetric metric;
    int? categoryId;

    if (text.contains('upcoming') ||
        text.contains('recurring') ||
        text.contains('subscription') ||
        text.contains('bills')) {
      metric = AiSummaryMetric.upcomingRecurring;
    } else if ((text.contains('top') ||
            text.contains('biggest') ||
            text.contains('most')) &&
        (text.contains('categor') ||
            text.contains('spend') ||
            text.contains('spent'))) {
      metric = AiSummaryMetric.topCategory;
    } else if (text.contains('balance') ||
        text.contains('net') ||
        text.contains('left') ||
        text.contains('saved')) {
      metric = AiSummaryMetric.netBalance;
    } else if (_incomeWords.any(text.contains) ||
        text.contains('earn') ||
        text.contains('made')) {
      metric = AiSummaryMetric.totalIncome;
    } else if (text.contains('spend') ||
        text.contains('spent') ||
        text.contains('spending') ||
        text.contains('expense') ||
        text.contains('cost')) {
      categoryId = _matchCategory(text, categories, isExpense: true)?.id;
      metric = categoryId != null
          ? AiSummaryMetric.categorySpending
          : AiSummaryMetric.totalSpending;
    } else {
      return null;
    }

    return AiIntent(
      type: AiIntentType.summaryRequest,
      confidence: 0.85,
      message: '',
      summaryRequest: AiSummaryRequest(
        metric: metric,
        startDate: period.start,
        endDate: period.end,
        categoryId: categoryId,
      ),
    );
  }

  AiIntent? _parseAddTransaction(String text, List<Category> categories) {
    final amountMatch = _amountPattern.firstMatch(text);
    if (amountMatch == null) return null;

    final amount =
        double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    if (amount == null || amount <= 0) return null;

    final isIncome = _incomeWords.any(text.contains);
    final hasVerb = isIncome || _expenseVerbs.any(text.contains);
    final wordCount = text.split(RegExp(r'\s+')).length;
    // Without a verb, only accept short "coffee 200" style messages —
    // anything longer is too ambiguous to log silently.
    if (!hasVerb && wordCount > 4) return null;

    final date = _parseTransactionDate(text);
    final category =
        _matchCategory(text, categories, isExpense: !isIncome);
    final title = _extractTitle(text, amountMatch.group(0)!, category?.name) ??
        category?.name ??
        (isIncome ? 'Income' : 'Expense');

    return AiIntent(
      type: AiIntentType.addTransaction,
      confidence: 0.9,
      message: '',
      transaction: AiTransactionDraft(
        title: title,
        amount: amount,
        isExpense: !isIncome,
        date: date,
        categoryId: category?.id,
        isRecurring:
            text.contains('every month') || text.contains('monthly'),
        needsCategoryReview: category == null,
      ),
    );
  }

  Category? _matchCategory(
    String text,
    List<Category> categories, {
    required bool isExpense,
  }) {
    Category? best;
    for (final category in categories) {
      if (category.id == null || category.isExpense != isExpense) continue;
      final name = category.name.toLowerCase();
      if (text.contains(name)) {
        if (best == null || name.length > best.name.length) {
          best = category;
        }
      }
    }
    return best;
  }

  String? _extractTitle(String text, String amountToken, String? categoryName) {
    var cleaned = text.replaceAll(amountToken.trim(), ' ');

    const noiseWords = [
      'add',
      'log',
      'new',
      'an',
      'a',
      'my',
      'i',
      'me',
      'spent',
      'paid',
      'bought',
      'purchased',
      'purchase',
      'expense',
      'income',
      'earned',
      'received',
      'got',
      'for',
      'on',
      'of',
      'at',
      'in',
      'rs',
      'rs.',
      'inr',
      'usd',
      'dollars',
      'rupees',
      'today',
      'yesterday',
      'tomorrow',
      'every',
      'month',
      'monthly',
    ];

    final words = cleaned
        .split(RegExp(r'[\s,]+'))
        .where((word) =>
            word.isNotEmpty &&
            !noiseWords.contains(word) &&
            double.tryParse(word.replaceAll(',', '')) == null)
        .toList();

    if (words.isEmpty) return null;

    final title = words.join(' ').trim();
    if (title.isEmpty) return null;

    // Capitalize each word for a tidy transaction title.
    return title
        .split(' ')
        .map((word) =>
            word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  DateTime _parseTransactionDate(String text) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (text.contains('yesterday')) {
      return today.subtract(const Duration(days: 1));
    }
    if (text.contains('tomorrow')) {
      return today.add(const Duration(days: 1));
    }
    return today;
  }

  ({DateTime start, DateTime end}) _parsePeriod(String text) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (text.contains('today')) {
      return (start: today, end: today);
    }
    if (text.contains('yesterday')) {
      final yesterday = today.subtract(const Duration(days: 1));
      return (start: yesterday, end: yesterday);
    }
    if (text.contains('this week')) {
      final start = today.subtract(Duration(days: today.weekday - 1));
      return (start: start, end: today);
    }
    if (text.contains('last week')) {
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      return (
        start: thisWeekStart.subtract(const Duration(days: 7)),
        end: thisWeekStart.subtract(const Duration(days: 1)),
      );
    }
    if (text.contains('last month')) {
      return (
        start: DateTime(now.year, now.month - 1, 1),
        end: DateTime(now.year, now.month, 0),
      );
    }
    if (text.contains('this year')) {
      return (start: DateTime(now.year, 1, 1), end: today);
    }
    if (text.contains('last year')) {
      return (
        start: DateTime(now.year - 1, 1, 1),
        end: DateTime(now.year - 1, 12, 31),
      );
    }
    // Default to the current month.
    return (
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }
}
