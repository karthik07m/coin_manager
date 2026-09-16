import 'package:math_expressions/math_expressions.dart';

import '../models/account.dart';
import '../models/ai_intent.dart';
import '../models/category.dart';

/// On-device parser for common finance commands so the chat works instantly,
/// offline, and without a configured AI function URL. Handles structured
/// phrases like "add expense 200 coffee", "spent 1.5k on groceries last
/// friday from chase", "transfer 200 from chase to cash", "what's my net
/// worth?", "find netflix", "biggest expense this month", or a bare
/// "and last month?" follow-up. Returns null when the message is too
/// free-form, letting the caller fall back to the remote AI.
class AiLocalParser {
  /// A number with optional thousands separators (Western or Indian
  /// grouping), decimals, and a k/lakh multiplier. Currency tokens are
  /// stripped before matching so "rs.200", "₹200" and "200 bucks" all work.
  static final RegExp _amountPattern = RegExp(
    r'(?<![\w.])(\d[\d,]*(?:\.\d+)?)\s*(k|lakh|lac)?(?![\w.])',
  );
  static final RegExp _currencyTokens = RegExp(
    r'[₹$€£]|(?<![a-z])(?:rs\.?|inr|usd|eur|gbp|rupees?|bucks|dollars?|euros?|pounds?)(?![a-z])',
    caseSensitive: false,
  );
  static const _monthRe =
      r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t|tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';

  static const _incomeWords = [
    'income',
    'salary',
    'earned',
    'received',
    'refund',
    'bonus',
    'got paid',
    'cashback',
    'dividend',
    'freelance',
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

  /// Phrasings that ask for a behavioural read of spending. Kept separate
  /// from [_questionWords] because these are usually written as statements
  /// ("my spending habits"), so they carry no question word to match on.
  static const _habitWords = [
    'habit',
    'pattern',
    'insight',
    'trend',
    'behaviour',
    'behavior',
    'how am i doing',
    'analyse my spending',
    'analyze my spending',
    // How people actually ask for advice. Without these, "any suggestions?"
    // and "how can I save money?" fell through as unsupported even though
    // the app had advice to give.
    'suggestion',
    'suggest',
    'advice',
    'advise',
    'recommend',
    'tips',
    'tip for',
    'save money',
    'saving money',
    'cut back',
    'cut down',
    'reduce my spending',
    'spend less',
    'where am i wasting',
    'what should i do',
    'help me budget',
  ];

  /// Month-over-month phrasings. Shared by the summary gate and the metric
  /// pick so they can never disagree.
  static const _compareWords = [
    'compare',
    'vs last',
    'versus last',
    'than last month',
    'last month vs',
    'month over month',
    'month on month',
    'more than last',
    'less than last',
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

  /// Everyday words and merchants mapped to the kind of category they belong
  /// in. The right-hand side is matched against the user's own category
  /// names, so "coffee" lands in "Food", "Dining Out" or "Cafe" — whichever
  /// exists. First hit wins, so more specific groups come first.
  static const _categoryHints = <(List<String>, List<String>)>[
    (
      ['grocer', 'vegetable', 'milk', 'bigbasket', 'blinkit', 'zepto',
        'supermarket', 'walmart', 'costco', 'dmart', 'instamart'],
      ['grocer', 'supermarket', 'food'],
    ),
    (
      ['coffee', 'tea', 'chai', 'lunch', 'dinner', 'breakfast', 'brunch',
        'snack', 'pizza', 'burger', 'restaurant', 'cafe', 'swiggy', 'zomato',
        'dominos', 'starbucks', 'mcdonald', 'kfc', 'biryani', 'meal', 'food',
        'juice', 'beer', 'drinks'],
      ['food', 'dining', 'restaurant', 'eat', 'meal', 'cafe'],
    ),
    (
      ['electricity', 'water bill', 'internet', 'wifi', 'broadband',
        'recharge', 'phone bill', 'mobile bill', 'gas bill', 'power bill'],
      ['utilit', 'bill', 'phone', 'internet'],
    ),
    (
      ['uber', 'ola', 'lyft', 'taxi', 'cab', 'bus', 'metro', 'train', 'auto',
        'rickshaw', 'petrol', 'diesel', 'fuel', 'parking', 'toll', 'rapido'],
      ['transit', 'transport', 'commute', 'fuel', 'car', 'travel'],
    ),
    (
      ['netflix', 'spotify', 'prime video', 'hotstar', 'youtube premium',
        'subscription', 'icloud', 'chatgpt', 'apple music', 'disney'],
      ['subscription', 'entertainment'],
    ),
    (
      ['movie', 'cinema', 'concert', 'game', 'gaming', 'pvr', 'theatre',
        'theater', 'party'],
      ['entertainment', 'fun', 'leisure'],
    ),
    (
      ['amazon', 'flipkart', 'myntra', 'shoes', 'clothes', 'shirt', 'dress',
        'jeans', 'shopping', 'mall', 'ikea', 'gift'],
      ['shopping', 'clothes', 'apparel', 'gift'],
    ),
    (
      ['doctor', 'medicine', 'pharmacy', 'hospital', 'clinic', 'dentist',
        'gym', 'yoga'],
      ['health', 'medical', 'fitness'],
    ),
    (['rent', 'maintenance'], ['rent', 'housing', 'home']),
    (
      ['hotel', 'trip', 'vacation', 'holiday', 'airbnb', 'flight', 'ticket'],
      ['travel', 'trip', 'vacation'],
    ),
    (['salary', 'paycheck', 'payroll', 'wages'], ['salary', 'income', 'pay']),
    (['bonus'], ['bonus']),
    (
      ['dividend', 'stock', 'shares', 'mutual fund', 'sip', 'interest'],
      ['stock', 'invest', 'dividend', 'interest'],
    ),
  ];

  static const _weekdays = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday',
    'sunday',
  ];
  static const _months = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct',
    'nov', 'dec',
  ];

  /// [previous] is the last summary the user asked for; a bare period such
  /// as "and last month?" re-asks it for the new period.
  AiIntent? tryParse({
    required String message,
    required List<Category> categories,
    List<Account> accounts = const [],
    AiSummaryRequest? previous,
  }) {
    final text = message.trim().toLowerCase();
    if (text.isEmpty) return null;

    final simple = _parseSimple(text);
    if (simple != null) return simple;

    final edit = _parseEdit(text);
    if (edit != null) return edit;

    final outOfScope = _parseOutOfScope(text);
    if (outOfScope != null) return outOfScope;

    final calc = _parseCalculation(text);
    if (calc != null) return calc;

    // Action/query intents that reference accounts or budgets take priority
    // over the generic summary/add flows.
    final transfer = _parseTransfer(text, accounts);
    if (transfer != null) return transfer;

    final budget = _parseBudgetQuery(text);
    if (budget != null) return budget;

    final accountQuery = _parseAccountQuery(text, accounts);
    if (accountQuery != null) return accountQuery;

    final lookup = _parseLookup(text);
    if (lookup != null) return lookup;

    final followUp = _parseFollowUp(text, previous);
    if (followUp != null) return followUp;

    // "add ... " / "log ... " is always a new entry, even when the note text
    // happens to contain a summary keyword ("add expense 20 habit tracker").
    final isEntry = text.startsWith('add ') || text.startsWith('log ');
    // Comparisons carry no question word ("compare this month to last"),
    // so they need their own entry to the summary branch or they fall
    // through to the cloud.
    final asksSummary = _questionWords.any(text.contains) ||
        _habitWords.any(text.contains) ||
        _compareWords.any(text.contains);
    if (asksSummary && !isEntry) {
      return _parseSummary(text, categories);
    }

    return _parseAddTransaction(text, categories, accounts);
  }

  /// Help, greetings and undo — one-word commands that need no data.
  AiIntent? _parseSimple(String text) {
    final bare = text.replaceAll(RegExp(r'[^a-z\s]'), '').trim();
    const undo = ['undo', 'undo that', 'undo last', 'delete last', 'remove last',
      'delete that', 'remove that', 'oops', 'undo it'];
    const help = ['help', 'what can you do', 'commands', 'how do i use this',
      'what do you do', 'how does this work', 'help me'];
    const greetings = ['hi', 'hello', 'hey', 'yo', 'thanks', 'thank you',
      'thankyou', 'good morning', 'good afternoon', 'good evening', 'ok',
      'okay', 'cool', 'nice', 'great', 'hi there', 'hello there'];
    if (undo.contains(bare)) {
      return const AiIntent(type: AiIntentType.undo, confidence: 1, message: '');
    }
    if (help.contains(bare)) {
      return const AiIntent(type: AiIntentType.help, confidence: 1, message: '');
    }
    // Pending drafts and transfers are resolved before parsing, so a bare
    // "yes" arriving here has nothing to agree to. Answering locally keeps it
    // from spending a cloud credit on a word with no object.
    const stray = ['yes', 'yeah', 'yep', 'sure', 'no', 'nope', 'nah',
      'confirm', 'cancel', 'do it', 'go ahead'];
    if (stray.contains(bare)) {
      return const AiIntent(
        type: AiIntentType.unsupported,
        confidence: 1,
        message: 'Nothing is waiting on a yes or no right now. Log something '
            'like "coffee 150", or ask me how your month is going.',
      );
    }
    if (greetings.contains(bare)) {
      return AiIntent(
          type: AiIntentType.smallTalk, confidence: 1, message: bare);
    }
    return null;
  }

  /// Changing or removing something already saved: "change that to 200",
  /// "delete the coffee from yesterday", "remove netflix". The words after
  /// the verb are kept as a search term; the provider finds the transaction
  /// and asks before touching it, because this is real money.
  AiIntent? _parseEdit(String text) {
    const pronouns = ['that', 'this', 'it', 'last', 'previous', 'the last',
      'that one', 'last one'];

    AiIntent edit(AiEditRequest request) => AiIntent(
          type: AiIntentType.editTransaction,
          confidence: 0.9,
          message: '',
          edit: request,
        );

    /// Strips filler so "the coffee i added yesterday" points at "coffee".
    String? clean(String raw, String periodToken) {
      // Guarded: replaceAll('', ' ') inserts a space between every character,
      // which turned "monthly income" into "m o n t h l y n c o m e".
      var out = periodToken.isEmpty ? raw : raw.replaceAll(periodToken, ' ');
      out = out
          .replaceAll(
              RegExp(r'\b(the|my|a|an|that|this|i|we|added|logged|entered|'
                  r'saved|paid|spent|from|for|on|transaction|transactions|'
                  r'entry|entries|expense|expenses|payment|one)\b'),
              ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return out.isEmpty ? null : out;
    }

    // "change my budget to 5000" is not a transaction edit; let it fall
    // through to the budget branch, which explains where budgets are set.
    final changed = text.contains('budget')
        ? null
        : RegExp(r'^(?:change|edit|update|modify|correct|make)\s+(.+?)\s+to\s+(.+)$')
            .firstMatch(text);
    if (changed != null) {
      final amount = _parseAmount(changed.group(2)!);
      final target = changed.group(1)!.trim();
      if (amount == null) {
        return AiIntent.unsupported(
          "✋ I can only change the amount for now — try \"change that to 250\". "
          'For anything else, open the transaction on the Transactions tab.',
        );
      }
      final period = _matchPeriod(target);
      return edit(AiEditRequest(
        term: pronouns.contains(target)
            ? null
            : clean(target, period?.token ?? ''),
        newAmount: amount.value,
        start: period?.start,
        end: period?.end,
      ));
    }

    // A delete never carries an amount — "remove stains 200" is an expense
    // someone is logging, not a request to erase anything.
    final removed = RegExp(r'^(?:delete|remove)\s+(.+)$').firstMatch(text);
    if (removed != null && _parseAmount(text) == null) {
      final target = removed.group(1)!.trim();
      final period = _matchPeriod(target);
      return edit(AiEditRequest(
        isDelete: true,
        term: pronouns.contains(target)
            ? null
            : clean(target, period?.token ?? ''),
        start: period?.start,
        end: period?.end,
      ));
    }

    return null;
  }

  /// Asks the assistant genuinely cannot serve. Caught explicitly so they get
  /// an honest "not yet" instead of being bent into the nearest supported
  /// answer: "change that to 200" used to log a brand new 200 expense titled
  /// "Change That", and "my average monthly spend" answered with this
  /// month's total as though that were the average.
  AiIntent? _parseOutOfScope(String text) {
    if (text.contains('budget') &&
        RegExp(r'^(set|create|make|add|change|update|increase|decrease|reduce|raise|lower)\b')
            .hasMatch(text)) {
      return AiIntent.unsupported(
        "✋ I can't set budgets yet — the Budget tab does that. Once one is "
        'set, ask me "how\'s my budget?" any time.',
      );
    }

    if (RegExp(r'\b(remind me|reminder|notify me|alert me)\b').hasMatch(text)) {
      return AiIntent.unsupported(
        "✋ I can't set reminders. Adding the payment as a recurring "
        'transaction gets you a heads-up instead — try "rent 25000 every '
        'month".',
      );
    }

    if (RegExp(r'\b(afford|should i buy|worth buying|can i buy)\b')
        .hasMatch(text)) {
      return AiIntent.unsupported(
        "✋ I can't tell you whether something is affordable — that depends on "
        'plans I cannot see. What I can show you is the room you have left: '
        'ask "how\'s my budget?" or "what\'s my net worth?".',
      );
    }

    final aboutMoney = RegExp(
            r'\b(spend|spent|spending|expense|expenses|income|earn|earned|save|saved|savings|cost|costs)\b')
        .hasMatch(text);
    if (aboutMoney &&
        RegExp(r'\b(average|avg|typical|typically|usually|normally)\b')
            .hasMatch(text)) {
      return AiIntent.unsupported(
        "✋ I can't work out averages yet, and I'd rather say so than hand "
        'you one period\'s total as if it were one. Try "how much did I '
        'spend last month?" or "compare this month vs last".',
      );
    }

    return null;
  }

  /// "2400/3", "what's 15% of 2400", "= 199*12". Only pure arithmetic —
  /// anything with letters other than the lead-in is someone's note text.
  AiIntent? _parseCalculation(String text) {
    var expr = text
        .replaceFirst(
            RegExp(r"^(what'?s|what is|calculate|calc|compute|=)\s*"), '')
        .replaceAll('?', '')
        .replaceAll(_currencyTokens, '')
        .replaceAllMapped(
            RegExp(r'(\d)\s*%\s*of\s*'), (m) => '${m[1]}/100*')
        .replaceAll('%', '/100')
        .replaceAll('x', '*')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll(',', '')
        .trim();
    if (!RegExp(r'^[\d\s+\-*/().]+$').hasMatch(expr)) return null;
    if (!RegExp(r'[+\-*/]').hasMatch(expr) || !RegExp(r'\d').hasMatch(expr)) {
      return null;
    }
    try {
      final value = RealEvaluator(ContextModel())
          .evaluate(GrammarParser().parse(expr))
          .toDouble();
      if (!value.isFinite) return null;
      return AiIntent(
        type: AiIntentType.calculation,
        confidence: 1,
        message: value == value.roundToDouble()
            ? value.toInt().toString()
            : value.toStringAsFixed(2),
      );
    } catch (_) {
      return null;
    }
  }

  /// "transfer 200 from chase to cash", "move 50 chase to cash",
  /// "pay 100 to amazon visa from chase".
  AiIntent? _parseTransfer(String text, List<Account> accounts) {
    final wantsTransfer = text.contains('transfer') ||
        text.contains('move ') ||
        (text.contains('pay') && text.contains(' to '));
    if (!wantsTransfer || accounts.length < 2) return null;

    final amount = _parseAmount(text)?.value;
    if (amount == null) return null;

    // Find every account whose name appears in the text, in order.
    final found = <({Account acc, int idx})>[];
    for (final a in accounts) {
      if (a.id == null || a.name.trim().isEmpty) continue;
      final idx = text.indexOf(a.name.toLowerCase());
      if (idx >= 0) found.add((acc: a, idx: idx));
    }
    if (found.length < 2) return null;
    found.sort((x, y) => x.idx.compareTo(y.idx));

    // Default: first mentioned = source, second = destination; explicit
    // "from X" / "to Y" phrasing overrides that.
    Account from = found[0].acc;
    Account to = found[1].acc;
    for (final m in found) {
      final before = text.substring(0, m.idx).trimRight();
      if (before.endsWith('from')) from = m.acc;
      if (before.endsWith('to') ||
          before.endsWith('into') ||
          before.endsWith('onto')) {
        to = m.acc;
      }
    }
    if (from.id == to.id) return null;

    return AiIntent(
      type: AiIntentType.transfer,
      confidence: 0.9,
      message: '',
      transfer: AiTransferDraft(
        amount: amount,
        fromAccountId: from.id!,
        toAccountId: to.id!,
        fromName: from.name,
        toName: to.name,
      ),
    );
  }

  /// "how's my budget", "am I over budget", "budget left?", "how much can I
  /// spend today", "safe to spend".
  AiIntent? _parseBudgetQuery(String text) {
    const allowance = ['can i spend', 'safe to spend', 'left to spend',
      'spend per day', 'daily limit', 'daily allowance', 'daily budget',
      // Forward-looking phrasings. Without these they fell through to the
      // net-balance metric, which answers with money already spent — a
      // different question wearing the same words.
      'will i have left', 'left at the end', 'left for the rest',
      'rest of the month'];
    const cues = ['how', 'left', 'remaining', 'over', 'status', 'am i',
      'much', 'doing', '?'];
    final asksBudget = text.contains('budget') && cues.any(text.contains);
    if (!asksBudget && !allowance.any(text.contains)) return null;
    return const AiIntent(
      type: AiIntentType.budgetQuery,
      confidence: 0.85,
      message: '',
    );
  }

  /// "what's my net worth", "chase balance", "how much money do I have".
  AiIntent? _parseAccountQuery(String text, List<Account> accounts) {
    if (text.contains('worth')) {
      return const AiIntent(
        type: AiIntentType.accountQuery,
        confidence: 0.9,
        message: '',
        accountQuery: AiAccountQuery(),
      );
    }

    final named = _matchAccount(text, accounts);
    final asksBalance = text.contains('balance') ||
        text.contains('how much money') ||
        text.contains('money do i have') ||
        text.contains('how much do i have');

    if (named != null && (asksBalance || text.contains('how much'))) {
      return AiIntent(
        type: AiIntentType.accountQuery,
        confidence: 0.9,
        message: '',
        accountQuery: AiAccountQuery(accountId: named.id),
      );
    }
    if (asksBalance &&
        (text.contains('account') || text.contains('all my'))) {
      return const AiIntent(
        type: AiIntentType.accountQuery,
        confidence: 0.85,
        message: '',
        accountQuery: AiAccountQuery(),
      );
    }
    return null;
  }

  /// Transaction lookups: "find netflix", "when did I last pay rent",
  /// "show my uber transactions", "recent transactions", "biggest expense".
  AiIntent? _parseLookup(String text) {
    final period = _matchPeriod(text);
    final ({DateTime start, DateTime end}) range =
        period == null ? _defaultPeriod() : (start: period.start, end: period.end);
    // A search defaults to the whole history, not this month: "when did I
    // last pay rent" is usually asking about something older than that.
    final ({DateTime start, DateTime end}) searchRange = period == null
        ? (start: DateTime(2000), end: DateTime.now())
        : (start: period.start, end: period.end);
    AiIntent summary(AiSummaryMetric metric, {String? term,
        ({DateTime start, DateTime end})? within}) {
      final r = within ?? range;
      return AiIntent(
        type: AiIntentType.summaryRequest,
        confidence: 0.85,
        message: '',
        summaryRequest: AiSummaryRequest(
          metric: metric,
          startDate: r.start,
          endDate: r.end,
          searchTerm: term,
        ),
      );
    }

    final stripped =
        period == null ? text : text.replaceAll(period.token, ' ');

    const noun =
        r'(?:\s+(?:transactions?|expenses?|payments?|purchases?|entries))';
    final explicit = RegExp(
      r'^(?:find|search(?: for)?|look ?up|when did i(?: last)? (?:pay for|pay|buy|spend on))\s+(.+?)'
      '$noun?'
      r'\s*\??$',
    ).firstMatch(stripped.trim());
    final listed = RegExp(
      r'^(?:show|list)(?: me)?(?: all)?(?: my)?\s+(.+?)' '$noun' r'\s*\??$',
    ).firstMatch(stripped.trim());
    final term = (explicit ?? listed)?.group(1)!.trim();
    // Whole words, so "netflix" is not mistaken for a net-balance question.
    const notTerms = ['recent', 'latest', 'last', 'all', 'my', 'the', 'top',
      'category', 'categories', 'spend', 'spending', 'summary', 'budget',
      'upcoming', 'recurring', 'income', 'balance', 'habit', 'habits', 'net',
      'total', 'bills', 'subscriptions', 'compare', 'biggest', 'largest',
      'expenses', 'transactions'];
    if (term != null &&
        term.isNotEmpty &&
        !term.split(' ').any(notTerms.contains)) {
      return summary(AiSummaryMetric.searchTransactions,
          term: term, within: searchRange);
    }

    final wantsLargest = RegExp(
            r'\b(biggest|largest|most expensive|highest)\b')
        .hasMatch(text);
    final aboutTxn = RegExp(
            r'\b(expense|purchase|transaction|payment|spend|buy)\w*')
        .hasMatch(text);
    if (wantsLargest && aboutTxn && !text.contains('categor')) {
      return summary(AiSummaryMetric.largestExpense);
    }

    final wantsRecent = RegExp(r'\b(recent|latest|last few)\b').hasMatch(text) ||
        RegExp(r'^what did i (spend on|buy|pay for)').hasMatch(text) ||
        RegExp(r'^(show|list)( me)?( my)? (transactions|expenses)').hasMatch(text);
    if (wantsRecent && aboutTxn) {
      return summary(AiSummaryMetric.recentTransactions);
    }
    return null;
  }

  /// "and last month?", "this week", "what about yesterday" — re-ask the
  /// previous question for a different period.
  AiIntent? _parseFollowUp(String text, AiSummaryRequest? previous) {
    if (previous == null) return null;
    final period = _matchPeriod(text);
    if (period == null) return null;
    final rest = text
        .replaceAll(period.token, ' ')
        .replaceAll(RegExp(r'\b(and|what about|how about|for|the same|same|in|on|now|then)\b'), ' ')
        .replaceAll(RegExp(r'[^a-z]'), '')
        .trim();
    if (rest.isNotEmpty) return null;
    return AiIntent(
      type: AiIntentType.summaryRequest,
      confidence: 0.8,
      message: '',
      summaryRequest: previous.withPeriod(period.start, period.end),
    );
  }

  AiIntent? _parseSummary(String text, List<Category> categories) {
    final matched = _matchPeriod(text);
    final ({DateTime start, DateTime end}) period = matched == null
        ? _defaultPeriod()
        : (start: matched.start, end: matched.end);

    AiSummaryMetric metric;
    int? categoryId;

    // Checked before the plain spending metrics: "spending habits" and
    // "spending pattern" both contain "spend", so a later branch would
    // swallow them and answer with a bare total instead.
    // Before habits: "compare my spending" contains "spending".
    if (_compareWords.any(text.contains)) {
      metric = AiSummaryMetric.monthComparison;
    } else if (_habitWords.any(text.contains)) {
      metric = AiSummaryMetric.spendingHabits;
    } else if (text.contains('upcoming') ||
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
        text.contains('save')) {
      metric = AiSummaryMetric.netBalance;
    } else if (_incomeWords.any(text.contains) ||
        text.contains('earn') ||
        text.contains('made')) {
      metric = AiSummaryMetric.totalIncome;
    } else if (text.contains('spend') ||
        text.contains('spent') ||
        text.contains('spending') ||
        text.contains('expense') ||
        text.contains('cost') ||
        // "how much on food this month" carries no verb at all, and used to
        // fall through to the cloud for a question answerable on-device.
        text.contains('how much')) {
      final pool = categories
          .where((c) => c.id != null && c.isExpense)
          .toList();
      categoryId = _matchCategoryByName(text, pool)?.id;
      if (categoryId != null) {
        metric = AiSummaryMetric.categorySpending;
      } else {
        // "how much did I spend at swiggy" used to be answered with the whole
        // Food category — the right number for a question nobody asked. Search
        // the ledger for the word they actually used instead.
        final hint = _matchCategoryHint(text);
        if (hint != null) {
          return AiIntent(
            type: AiIntentType.summaryRequest,
            confidence: 0.85,
            message: '',
            summaryRequest: AiSummaryRequest(
              metric: AiSummaryMetric.searchTransactions,
              startDate: period.start,
              endDate: period.end,
              searchTerm: hint,
            ),
          );
        }
        metric = AiSummaryMetric.totalSpending;
      }
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

  AiIntent? _parseAddTransaction(
    String text,
    List<Category> categories,
    List<Account> accounts,
  ) {
    // Dates first, so "on 5 jan" and "3 days ago" never read as amounts.
    final date = _parseTransactionDate(text);
    final withoutDate =
        date.token.isEmpty ? text : text.replaceAll(date.token, ' ');

    final amount = _parseAmount(withoutDate);
    if (amount == null) {
      // "starbucks", or "add lunch", is someone starting to log and leaving
      // out the number. Asking for it beats "I didn't quite catch that", and
      // beats spending a cloud credit to be told the same thing.
      final named = _extractTitle(withoutDate, null);
      if (named != null &&
          named.split(' ').length <= 2 &&
          (_matchCategoryHint(text) != null ||
              _matchCategory(text, categories, isExpense: true) != null)) {
        return AiIntent.unsupported('How much was ${named.toLowerCase()}?');
      }
      return null;
    }

    final isIncome = _incomeWords.any(text.contains);
    final hasVerb = isIncome || _expenseVerbs.any(text.contains);
    final wordCount = text.split(RegExp(r'\s+')).length;
    // Without a verb, only accept short "coffee 200" style messages —
    // anything longer is too ambiguous to log silently.
    if (!hasVerb && wordCount > 5) return null;

    final account = _matchAccount(withoutDate, accounts);
    final category =
        _matchCategory(withoutDate, categories, isExpense: !isIncome);
    final title = _extractTitle(
          withoutDate.replaceAll(amount.token, ' '),
          account?.name,
        ) ??
        category?.name ??
        (isIncome ? 'Income' : 'Expense');

    return AiIntent(
      type: AiIntentType.addTransaction,
      confidence: 0.9,
      message: '',
      transaction: AiTransactionDraft(
        title: title,
        amount: amount.value,
        isExpense: !isIncome,
        date: date.date,
        categoryId: category?.id,
        accountId: account?.id,
        isRecurring:
            text.contains('every month') || text.contains('monthly'),
        needsCategoryReview: category == null,
      ),
    );
  }

  /// The largest number in the message, not the first one. "2 coffees 300"
  /// is a quantity followed by a price, and taking the first match logged it
  /// as a 2 rupee expense — a silent 100x error the user had to spot in the
  /// draft card. Quantities are smaller than prices often enough that the
  /// largest candidate is right far more often than the leftmost one.
  ({double value, String token})? _parseAmount(String text) {
    final cleaned = text.replaceAll(_currencyTokens, ' ');
    ({double value, String token})? best;
    for (final match in _amountPattern.allMatches(cleaned)) {
      var value = double.tryParse(match.group(1)!.replaceAll(',', ''));
      if (value == null || value <= 0) continue;
      switch (match.group(2)) {
        case 'k':
          value *= 1000;
        case 'lakh':
        case 'lac':
          value *= 100000;
      }
      if (best == null || value > best.value) {
        best = (value: value, token: match.group(0)!);
      }
    }
    return best;
  }

  Account? _matchAccount(String text, List<Account> accounts) {
    Account? best;
    for (final a in accounts) {
      if (a.id == null || a.name.trim().isEmpty) continue;
      final name = a.name.toLowerCase();
      if (text.contains(name) &&
          (best == null || name.length > best.name.length)) {
        best = a;
      }
    }
    return best;
  }

  Category? _matchCategory(
    String text,
    List<Category> categories, {
    required bool isExpense,
  }) {
    final pool = categories
        .where((c) => c.id != null && c.isExpense == isExpense)
        .toList();

    // The user's own category name in the message beats any guess.
    final named = _matchCategoryByName(text, pool);
    if (named != null) return named;

    for (final (triggers, kinds) in _categoryHints) {
      if (!triggers.any(text.contains)) continue;
      for (final kind in kinds) {
        for (final category in pool) {
          if (category.name.toLowerCase().contains(kind)) return category;
        }
      }
    }
    return null;
  }

  /// The user's own category whose name they actually typed, or null.
  Category? _matchCategoryByName(String text, List<Category> pool) {
    Category? best;
    for (final category in pool) {
      final name = category.name.toLowerCase();
      if (category.id == null) continue;
      if (text.contains(name) &&
          (best == null || name.length > best.name.length)) {
        best = category;
      }
    }
    return best;
  }

  /// The merchant or everyday word in the message that only *hints* at a
  /// category — "swiggy", "coffee", "netflix". Returned so a question about
  /// one can be answered about that word rather than about the whole
  /// category it happens to live in.
  String? _matchCategoryHint(String text) {
    for (final (triggers, _) in _categoryHints) {
      for (final trigger in triggers) {
        if (text.contains(trigger)) return trigger;
      }
    }
    return null;
  }

  String? _extractTitle(String text, String? accountName) {
    var cleaned = text;
    if (accountName != null) {
      cleaned = cleaned.replaceAll(accountName.toLowerCase(), ' ');
    }

    const noiseWords = [
      'add', 'log', 'new', 'an', 'a', 'my', 'i', 'me', 'spent', 'paid',
      'bought', 'purchased', 'purchase', 'expense', 'income', 'earned',
      'received', 'got', 'for', 'on', 'of', 'at', 'in', 'from', 'to', 'via',
      'using', 'with', 'by', 'the', 'rs', 'rs.', 'inr', 'usd', 'dollars',
      'rupees', 'bucks', 'today', 'yesterday', 'tomorrow', 'every', 'month',
      'monthly', 'account', 'card', 'and', 'worth', 'just', 'some',
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

  /// Returns the date the message refers to and the text that named it, so
  /// the caller can strip it before reading amounts and titles.
  ({DateTime date, String token}) _parseTransactionDate(String text) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (text.contains('day before yesterday')) {
      return (
        date: today.subtract(const Duration(days: 2)),
        token: 'day before yesterday',
      );
    }
    if (text.contains('yesterday')) {
      return (date: today.subtract(const Duration(days: 1)), token: 'yesterday');
    }
    if (text.contains('tomorrow')) {
      return (date: today.add(const Duration(days: 1)), token: 'tomorrow');
    }

    final ago = RegExp(r'(\d+) days? ago').firstMatch(text);
    if (ago != null) {
      return (
        date: today.subtract(Duration(days: int.parse(ago.group(1)!))),
        token: ago.group(0)!,
      );
    }

    // "last friday" / "on monday": the most recent such day before today.
    final weekday = RegExp(
      r'\b(?:last|on|this)?\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\b',
    ).firstMatch(text);
    if (weekday != null) {
      final target =
          _weekdays.indexWhere((d) => d.startsWith(weekday.group(1)!)) + 1;
      var back = (today.weekday - target) % 7;
      if (back == 0) back = 7;
      return (
        date: today.subtract(Duration(days: back)),
        token: weekday.group(0)!,
      );
    }

    // "5 jan", "jan 5", "on 5th", "on the 12th".
    final dayMonth = RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)?\s+' '$_monthRe' r'\b')
        .firstMatch(text);
    final monthDay = RegExp(r'\b' '$_monthRe' r'\s+(\d{1,2})(?:st|nd|rd|th)?\b')
        .firstMatch(text);
    if (dayMonth != null || monthDay != null) {
      final m = dayMonth ?? monthDay!;
      final day = int.parse(dayMonth != null ? m.group(1)! : m.group(2)!);
      final monthName = dayMonth != null ? m.group(2)! : m.group(1)!;
      final month = _months.indexOf(monthName.substring(0, 3)) + 1;
      var date = DateTime(now.year, month, day);
      if (date.isAfter(today)) date = DateTime(now.year - 1, month, day);
      return (date: date, token: m.group(0)!);
    }

    final onDay =
        RegExp(r'\bon (?:the )?(\d{1,2})(?:st|nd|rd|th)\b').firstMatch(text);
    if (onDay != null) {
      final day = int.parse(onDay.group(1)!);
      var date = DateTime(now.year, now.month, day);
      if (date.isAfter(today)) date = DateTime(now.year, now.month - 1, day);
      return (date: date, token: onDay.group(0)!);
    }

    return (date: today, token: '');
  }

  ({DateTime start, DateTime end}) _defaultPeriod() {
    final now = DateTime.now();
    return (
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  /// The period a message names, or null when it names none.
  ({DateTime start, DateTime end, String token})? _matchPeriod(String text) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));

    if (text.contains('today')) {
      return (start: today, end: today, token: 'today');
    }
    if (text.contains('yesterday')) {
      final y = today.subtract(const Duration(days: 1));
      return (start: y, end: y, token: 'yesterday');
    }
    if (text.contains('this week')) {
      return (start: thisWeekStart, end: today, token: 'this week');
    }
    if (text.contains('last week')) {
      return (
        start: thisWeekStart.subtract(const Duration(days: 7)),
        end: thisWeekStart.subtract(const Duration(days: 1)),
        token: 'last week',
      );
    }
    if (text.contains('last month')) {
      return (
        start: DateTime(now.year, now.month - 1, 1),
        end: DateTime(now.year, now.month, 0),
        token: 'last month',
      );
    }
    if (text.contains('this month')) {
      final p = _defaultPeriod();
      return (start: p.start, end: p.end, token: 'this month');
    }
    if (text.contains('this year')) {
      return (start: DateTime(now.year, 1, 1), end: today, token: 'this year');
    }
    if (text.contains('last year')) {
      return (
        start: DateTime(now.year - 1, 1, 1),
        end: DateTime(now.year - 1, 12, 31),
        token: 'last year',
      );
    }
    final lastDays = RegExp(r'(?:last|past) (\d+) days').firstMatch(text);
    if (lastDays != null) {
      final n = int.parse(lastDays.group(1)!);
      return (
        start: today.subtract(Duration(days: n - 1)),
        end: today,
        token: lastDays.group(0)!,
      );
    }
    // "in january" / "for aug" — a named month this year (or last, if it
    // hasn't happened yet).
    final named = RegExp(r'\b(?:in|for|during)\s+' '$_monthRe' r'\b')
        .firstMatch(text);
    if (named != null) {
      final month = _months.indexOf(named.group(1)!.substring(0, 3)) + 1;
      var year = now.year;
      if (month > now.month) year -= 1;
      return (
        start: DateTime(year, month, 1),
        end: DateTime(year, month + 1, 0),
        token: named.group(0)!,
      );
    }
    return null;
  }
}
