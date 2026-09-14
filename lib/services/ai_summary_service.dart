import 'package:intl/intl.dart';

import '../db/monthly_budget_db_helper.dart';
import '../db/transaction_db_helper.dart';
import '../models/ai_intent.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../utilities/budget_period.dart';
import '../utilities/functions.dart';
import 'spending_advisor.dart';

class AiSummaryService {
  final TransactionDBHelper _dbHelper;

  AiSummaryService({TransactionDBHelper? dbHelper})
      : _dbHelper = dbHelper ?? TransactionDBHelper();

  /// Converts a transaction's amount into the user's base currency. Defaults
  /// to the raw amount so the service still works standalone.
  double Function(Transaction)? _amountOf;

  double _amt(Transaction t) => _amountOf?.call(t) ?? t.amount;

  Future<String> buildSummary({
    required AiSummaryRequest request,
    required List<Category> categories,
    required String currencySymbol,
    required String currencyCode,
    double Function(Transaction)? amountOf,
  }) async {
    _amountOf = amountOf;

    if (request.metric == AiSummaryMetric.upcomingRecurring) {
      final upcoming = await _dbHelper.getAllUpcomingRecurringTransactions();
      return _formatUpcoming(upcoming, currencySymbol, currencyCode);
    }
    if (request.metric == AiSummaryMetric.searchTransactions) {
      return _search(request, categories, currencySymbol, currencyCode);
    }

    final rawTransactions = await _dbHelper.getTransactionsByType(
      startDate: request.startDate,
      endDate: DateTime(
        request.endDate.year,
        request.endDate.month,
        request.endDate.day,
        23,
        59,
        59,
      ),
    );

    // Transfers move money between the user's own accounts — they are not
    // spending or income, so they must never land in these totals (transfer
    // rows carry isExpense = true). Future-dated rows (generated recurring
    // instances later this month) are excluded too, so "you spent X this
    // month" matches what Home reports for the same period.
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final transactions = rawTransactions
        .where((t) => !t.isTransfer && !t.date.isAfter(todayEnd))
        .toList();

    switch (request.metric) {
      case AiSummaryMetric.totalSpending:
        final expenses =
            transactions.where((transaction) => transaction.isExpense).toList();
        final total = expenses.fold(0.0, (sum, t) => sum + _amt(t));
        if (expenses.isEmpty) {
          return '🎉 No expenses ${_periodText(request)} — your wallet thanks you!';
        }
        final header =
            '🧾 You spent ${_money(total, currencySymbol, currencyCode)} '
            '${_periodText(request)} across ${expenses.length} '
            'transaction${expenses.length == 1 ? '' : 's'}.';
        final breakdown = _topCategoryBreakdown(
          expenses,
          categories,
          total,
          currencySymbol,
          currencyCode,
        );
        return breakdown.isEmpty ? header : '$header\n\n$breakdown';
      case AiSummaryMetric.totalIncome:
        final total = transactions
            .where((transaction) => !transaction.isExpense)
            .fold(0.0, (sum, t) => sum + _amt(t));
        return '💰 Your income was ${_money(total, currencySymbol, currencyCode)} ${_periodText(request)}.';
      case AiSummaryMetric.netBalance:
        final income = transactions
            .where((transaction) => !transaction.isExpense)
            .fold(0.0, (sum, t) => sum + _amt(t));
        final expenses = transactions
            .where((transaction) => transaction.isExpense)
            .fold(0.0, (sum, t) => sum + _amt(t));
        final net = income - expenses;
        final emoji = net >= 0 ? '📈' : '📉';
        return '$emoji Your net balance was ${net >= 0 ? '+' : '-'}${_money(net.abs(), currencySymbol, currencyCode)} ${_periodText(request)} '
            '(income ${_money(income, currencySymbol, currencyCode)}, '
            'expenses ${_money(expenses, currencySymbol, currencyCode)}).';
      case AiSummaryMetric.categorySpending:
        return _categorySpending(
          transactions,
          categories,
          request,
          currencySymbol,
          currencyCode,
        );
      case AiSummaryMetric.topCategory:
        return _topCategory(
          transactions,
          categories,
          request,
          currencySymbol,
          currencyCode,
        );
      case AiSummaryMetric.spendingHabits:
        // Advice that cites the user's own budgets and last month's figures
        // needs data this method doesn't load, so it is prepared here and
        // handed to the formatter.
        final grounded = await _budgetGroundedAdvice(
          transactions,
          categories,
          request,
          currencySymbol,
          currencyCode,
        );
        return _spendingHabits(
          transactions,
          categories,
          request,
          currencySymbol,
          currencyCode,
          groundedAdvice: grounded,
        );
      case AiSummaryMetric.monthComparison:
        return _monthComparison(request, categories, currencySymbol,
            currencyCode);
      case AiSummaryMetric.largestExpense:
        return _largestExpense(
            transactions, categories, request, currencySymbol, currencyCode);
      case AiSummaryMetric.recentTransactions:
        return _recent(
            transactions, categories, request, currencySymbol, currencyCode);
      case AiSummaryMetric.upcomingRecurring:
      case AiSummaryMetric.searchTransactions:
        throw StateError('Handled before loading period transactions');
    }
  }

  /// "• Tue 3 Sep · Coffee · Food · -₹150" — one line per transaction.
  String _line(Transaction t, List<Category> categories, String symbol,
      String code) {
    final sign = t.isExpense ? '-' : '+';
    return '•  ${DateFormat('EEE d MMM').format(t.date)} · ${t.title} · '
        '${_categoryName(categories, t.categoryId)} · '
        '$sign${_money(_amt(t), symbol, code)}';
  }

  String _largestExpense(
    List<Transaction> transactions,
    List<Category> categories,
    AiSummaryRequest request,
    String symbol,
    String code,
  ) {
    final expenses = transactions.where((t) => t.isExpense).toList()
      ..sort((a, b) => _amt(b).compareTo(_amt(a)));
    if (expenses.isEmpty) {
      return '🎉 No expenses ${_periodText(request)} — nothing to rank!';
    }
    final total = expenses.fold(0.0, (sum, t) => sum + _amt(t));
    final top = expenses.first;
    final share = (_amt(top) / total * 100).round();
    final lines = <String>[
      '🏆 Biggest expense ${_periodText(request)}: **${top.title}** — '
          '${_money(_amt(top), symbol, code)} on '
          '${DateFormat('EEE d MMM').format(top.date)} '
          '(${_categoryName(categories, top.categoryId)}, $share% of the '
          'period\'s spending).',
    ];
    if (expenses.length > 1) {
      lines.add('');
      lines.add('**Runners-up**');
      for (final t in expenses.skip(1).take(3)) {
        lines.add(_line(t, categories, symbol, code));
      }
    }
    return lines.join('\n');
  }

  String _recent(
    List<Transaction> transactions,
    List<Category> categories,
    AiSummaryRequest request,
    String symbol,
    String code,
  ) {
    final sorted = List<Transaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    if (sorted.isEmpty) {
      return '🧘 Nothing recorded ${_periodText(request)}.';
    }
    final spent = sorted
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + _amt(t));
    final lines = <String>[
      '**${sorted.length} transaction${sorted.length == 1 ? '' : 's'} '
          '${_periodText(request)}** · spent ${_money(spent, symbol, code)}',
      '',
      for (final t in sorted.take(8)) _line(t, categories, symbol, code),
      if (sorted.length > 8) '…and ${sorted.length - 8} more.',
    ];
    return lines.join('\n');
  }

  /// Title search. Filtering in Dart is fine for a personal ledger.
  // ponytail: full-table scan; add a LIKE query if ledgers get huge.
  Future<String> _search(
    AiSummaryRequest request,
    List<Category> categories,
    String symbol,
    String code,
  ) async {
    final term = (request.searchTerm ?? '').trim().toLowerCase();
    if (term.isEmpty) return 'What should I look for?';
    final rows = await _dbHelper.getTransactionsByType(
      startDate: request.startDate,
      endDate: DateTime(request.endDate.year, request.endDate.month,
          request.endDate.day, 23, 59, 59),
    );
    final now = DateTime.now();
    final matches = rows
        .where((t) =>
            !t.date.isAfter(now) &&
            (t.title.toLowerCase().contains(term) ||
                _categoryName(categories, t.categoryId)
                    .toLowerCase()
                    .contains(term)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (matches.isEmpty) {
      return '🔍 No transactions matching "$term".';
    }
    final total = matches
        .where((t) => t.isExpense && !t.isTransfer)
        .fold(0.0, (sum, t) => sum + _amt(t));
    final last = matches.first;
    final ago = now.difference(last.date).inDays;
    final when = ago == 0
        ? 'today'
        : ago == 1
            ? 'yesterday'
            : '$ago days ago';
    final lines = <String>[
      '🔍 **${matches.length} match${matches.length == 1 ? '' : 'es'} for '
          '"$term"** · last one $when'
          '${total > 0 ? ' · ${_money(total, symbol, code)} total' : ''}',
      '',
      for (final t in matches.take(6)) _line(t, categories, symbol, code),
      if (matches.length > 6) '…and ${matches.length - 6} more.',
    ];
    return lines.join('\n');
  }

  /// Behavioural read of the period with real financial-advisor-style analysis:
  /// breaks spending into needs vs wants, identifies overspending patterns,
  /// compares weekday vs weekend, flags high-frequency small purchases, and
  /// delivers 2–3 tailored, actionable tips grounded in the user's numbers.

  /// This month against last, read the way a person would: same number of
  /// days in each, fixed bills set aside, and every big move explained.
  Future<String> _monthComparison(
    AiSummaryRequest request,
    List<Category> categories,
    String currencySymbol,
    String currencyCode,
  ) async {
    String m(double v) => _money(v, currencySymbol, currencyCode);
    String pct(double a, double b) =>
        b <= 0 ? '' : ' (${(((a - b) / b) * 100).abs().round()}%)';

    final anchor = request.endDate;
    final now = DateTime.now();
    final thisStart = BudgetPeriod.startOfMonth(anchor);
    final prevStart = DateTime(anchor.year, anchor.month - 1, 1);
    final thisName = DateFormat('MMMM').format(anchor);
    final prevName = DateFormat('MMMM').format(prevStart);

    // A month still in progress is compared over the same day count, or
    // "down 70%" on the 8th is just the calendar talking.
    final inProgress =
        anchor.year == now.year && anchor.month == now.month;
    final daysInThis = BudgetPeriod.daysInMonth(anchor);
    final daysInPrev = BudgetPeriod.daysInMonth(prevStart);
    final window = inProgress ? now.day.clamp(1, daysInPrev) : daysInThis;

    Future<List<Transaction>> load(DateTime start, int days) async {
      final end = DateTime(start.year, start.month, days, 23, 59, 59);
      final rows = await _dbHelper.getTransactionsByType(
          startDate: start, endDate: end);
      return rows.where((t) => t.isExpense && !t.isTransfer).toList();
    }

    final cur = await load(thisStart, window);
    final prev = await load(prevStart, window.clamp(1, daysInPrev));
    if (cur.isEmpty && prev.isEmpty) {
      return 'No spending in $thisName or $prevName yet, so there is '
          'nothing to compare.';
    }

    bool fixed(Transaction t) =>
        _isEssential(_categoryName(categories, t.categoryId), t);
    double sum(Iterable<Transaction> xs) =>
        xs.fold(0.0, (a, t) => a + _amt(t));

    final curDaily = sum(cur.where((t) => !fixed(t)));
    final prevDaily = sum(prev.where((t) => !fixed(t)));
    final curFixed = sum(cur.where(fixed));
    final prevFixed = sum(prev.where(fixed));

    final title = inProgress
        ? '$thisName so far vs $prevName (first $window days of each)'
        : '$thisName vs $prevName';
    final lines = <String>[title, ''];

    String trend(double a, double b) {
      if (b == 0 && a == 0) return 'nothing either month';
      if ((a - b).abs() < 1) return 'unchanged';
      return '${a > b ? 'up' : 'down'} ${m((a - b).abs())}${pct(a, b)}';
    }

    lines.add('Day-to-day spending: ${m(curDaily)} vs ${m(prevDaily)} — '
        '${trend(curDaily, prevDaily)}');
    lines.add('Fixed bills: ${m(curFixed)} vs ${m(prevFixed)} — '
        '${trend(curFixed, prevFixed)}');

    // Explain the day-to-day delta by category, then by cause.
    final curBy = <int, List<Transaction>>{};
    final prevBy = <int, List<Transaction>>{};
    for (final t in cur.where((t) => !fixed(t))) {
      curBy.putIfAbsent(t.categoryId, () => []).add(t);
    }
    for (final t in prev.where((t) => !fixed(t))) {
      prevBy.putIfAbsent(t.categoryId, () => []).add(t);
    }
    final movers = <MapEntry<int, double>>[];
    for (final id in {...curBy.keys, ...prevBy.keys}) {
      final d = sum(curBy[id] ?? const []) - sum(prevBy[id] ?? const []);
      if (d.abs() >= 1) movers.add(MapEntry(id, d));
    }
    movers.sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    if (movers.isNotEmpty) {
      lines.add('');
      lines.add('What changed');
      for (final e in movers.take(4)) {
        final name = _categoryName(categories, e.key);
        final c = curBy[e.key] ?? const <Transaction>[];
        final p = prevBy[e.key] ?? const <Transaction>[];
        final sign = e.value >= 0 ? '+' : '-';
        String why;
        if (p.isEmpty) {
          why = 'new this month';
        } else if (c.isEmpty) {
          why = 'nothing this month';
        } else {
          // One purchase carrying most of the move is a different story
          // from spending more often.
          final biggest = c.fold(0.0, (a, t) => _amt(t) > a ? _amt(t) : a);
          if (e.value > 0 && biggest >= e.value * 0.6) {
            why = 'mostly one ${m(biggest)} purchase';
          } else if (c.length != p.length) {
            why = '${c.length} vs ${p.length} transactions';
          } else {
            why = 'same count, larger amounts';
          }
        }
        lines.add('• $name $sign${m(e.value.abs())} — $why');
      }
    }

    // Verdict, then where the month lands if this keeps up.
    lines.add('');
    if ((curDaily - prevDaily).abs() < 1) {
      lines.add('Day-to-day spending is flat against $prevName.');
    } else {
      final top = movers.isNotEmpty
          ? _categoryName(categories, movers.first.key)
          : null;
      final change = prevDaily > 0
          ? ' ${(((curDaily - prevDaily) / prevDaily) * 100).abs().round()}%'
          : '';
      lines.add('Day-to-day spending is '
          '${curDaily > prevDaily ? 'up' : 'down'}$change'
          '${top != null ? ', driven mostly by $top' : ''}.');
    }
    if (inProgress && window < daysInThis && window > 0) {
      final fullPrev = sum(await load(prevStart, daysInPrev));
      final projected = curFixed + curDaily / window * daysInThis;
      lines.add('At this pace $thisName lands near ${m(projected)}, '
          'against ${m(fullPrev)} for all of $prevName.');
    }

    return lines.join('\n');
  }

  /// Advice drawn from the user's budgets and last month's spending, which
  /// is what makes it specific rather than generic thrift tips.
  Future<List<String>> _budgetGroundedAdvice(
    List<Transaction> transactions,
    List<Category> categories,
    AiSummaryRequest request,
    String currencySymbol,
    String currencyCode,
  ) async {
    try {
      final anchor = request.endDate;
      final monthStart = BudgetPeriod.startOfMonth(anchor);
      final previousMonth = DateTime(anchor.year, anchor.month - 1, 1);

      final previousRaw = await _dbHelper.getTransactionsByType(
        startDate: previousMonth,
        endDate: BudgetPeriod.endOfMonth(previousMonth),
      );
      final budgets = await MonthlyBudgetDBHelper()
          .getAllBudgetsForMonth(BudgetPeriod.keyFor(anchor));

      final now = DateTime.now();
      final isCurrentMonth =
          anchor.year == now.year && anchor.month == now.month;
      final daysInMonth = BudgetPeriod.daysInMonth(anchor);
      final daysElapsed = isCurrentMonth ? now.day : daysInMonth;

      final suggestions = SpendingAdvisor.suggest(
        monthExpenses: transactions
            .where((t) => t.isExpense && !t.date.isBefore(monthStart))
            .toList(),
        previousMonthExpenses:
            previousRaw.where((t) => !t.isTransfer).toList(),
        categoryNames: {
          for (final c in categories)
            if (c.id != null) c.id!: c.name,
        },
        categoryBudgets: budgets,
        fixedCategoryIds: {
          for (final c in categories)
            if (c.id != null && _essentialKeywords.any(c.name.toLowerCase().contains))
              c.id!,
        },
        amountOf: _amt,
        money: (value) => _money(value, currencySymbol, currencyCode),
        daysElapsed: daysElapsed,
        daysInMonth: daysInMonth,
      );

      return suggestions.map((s) => s.text).toList();
    } catch (e) {
      // Advice is a bonus on top of the summary; never fail the answer for it.
      return const [];
    }
  }

  String _spendingHabits(
    List<Transaction> transactions,
    List<Category> categories,
    AiSummaryRequest request,
    String currencySymbol,
    String currencyCode, {
    List<String> groundedAdvice = const [],
  }) {
    final expenses = transactions.where((t) => t.isExpense).toList();
    if (expenses.isEmpty) {
      return '🧘 No spending ${_periodText(request)}, so there\'s no pattern '
          'to read yet. Start tracking and I\'ll give you a full analysis!';
    }

    final income = transactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + _amt(t));
    final total = expenses.fold(0.0, (sum, t) => sum + _amt(t));

    // Count whole days in the period, capped at today.
    final now = DateTime.now();
    final start = DateTime(
        request.startDate.year, request.startDate.month, request.startDate.day);
    final requestedEnd = DateTime(
        request.endDate.year, request.endDate.month, request.endDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final end = requestedEnd.isAfter(today) ? today : requestedEnd;
    final dayCount = end.difference(start).inDays + 1;
    final days = dayCount < 1 ? 1 : dayCount;

    final perDay = total / days;
    final avgTransaction = total / expenses.length;

    // ── Needs vs Wants classification ──
    double needsTotal = 0, wantsTotal = 0;
    for (final t in expenses) {
      final catName = _categoryName(categories, t.categoryId);
      if (_isEssential(catName, t)) {
        needsTotal += _amt(t);
      } else {
        wantsTotal += _amt(t);
      }
    }
    final needsPct = total > 0 ? (needsTotal / total * 100).round() : 0;
    final wantsPct = total > 0 ? (wantsTotal / total * 100).round() : 0;

    // Behavioural patterns describe choices, so fixed commitments are
    // excluded. A mortgage that falls due on a Saturday is not weekend
    // habit — counting it produced "weekends cost 1698% more per day" and
    // advice to save $4,114 by spending less at weekends, which is money the
    // user cannot choose not to spend.
    final discretionary = expenses
        .where((t) => !_isEssential(_categoryName(categories, t.categoryId), t))
        .toList();

    // ── Heaviest weekday by amount (discretionary only) ──
    final byWeekday = <int, double>{};
    for (final t in discretionary) {
      byWeekday[t.date.weekday] = (byWeekday[t.date.weekday] ?? 0) + _amt(t);
    }
    final heaviestDay = byWeekday.isEmpty
        ? null
        : byWeekday.entries.reduce((a, b) => a.value >= b.value ? a : b);

    // ── Weekday vs weekend spending (discretionary only) ──
    double weekdaySpend = 0, weekendSpend = 0;
    int weekdayTxns = 0, weekendTxns = 0;
    for (final t in discretionary) {
      if (t.date.weekday >= 6) {
        weekendSpend += _amt(t);
        weekendTxns++;
      } else {
        weekdaySpend += _amt(t);
        weekdayTxns++;
      }
    }

    // ── Most-reached-for category (by count) ──
    final countByCategory = <int, int>{};
    for (final t in expenses) {
      countByCategory[t.categoryId] = (countByCategory[t.categoryId] ?? 0) + 1;
    }
    final mostFrequent =
        countByCategory.entries.reduce((a, b) => a.value >= b.value ? a : b);

    // ── Top spending category (by amount) ──
    final amtByCategory = <int, double>{};
    for (final t in expenses) {
      amtByCategory[t.categoryId] =
          (amtByCategory[t.categoryId] ?? 0) + _amt(t);
    }
    final topCategory =
        amtByCategory.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final topCatPct = (topCategory.value / total * 100).round();

    // ── No-spend days ──
    final spendingDays = expenses
        .map((t) => DateTime(t.date.year, t.date.month, t.date.day))
        .toSet()
        .length;
    final noSpendDays = days - spendingDays;

    // ── Savings rate (if income is available) ──
    final savingsRate = income > 0 ? ((income - total) / income * 100) : null;

    // ── Build the response ──
    String m(double v) => _money(v, currencySymbol, currencyCode);

    final lines = <String>[
      'Spending review ${_periodText(request)}',
      '',
      '**Overview**',
      '• Spent ${m(total)} across ${expenses.length} transactions',
      '• ${m(perDay)} a day, ${m(avgTransaction)} per transaction',
    ];

    if (income > 0) {
      lines.add(savingsRate != null && savingsRate >= 0
          ? '• Earned ${m(income)}, saved ${savingsRate.round()}%'
          : '• Earned ${m(income)}, overspent by ${m(total - income)}');
    }

    lines.addAll([
      '',
      '**Where it went**',
      '• Essentials ${m(needsTotal)} ($needsPct%)',
      '• Lifestyle ${m(wantsTotal)} ($wantsPct%)',
      '• Largest: ${_categoryName(categories, topCategory.key)} '
          '${m(topCategory.value)} ($topCatPct%)',
      '• Most frequent: ${_categoryName(categories, mostFrequent.key)}, '
          '${mostFrequent.value} times',
    ]);

    lines.addAll([
      '',
      '**Patterns**',
      if (heaviestDay != null)
        '• Busiest day for day-to-day spending: '
            '${_weekdayName(heaviestDay.key)}, ${m(heaviestDay.value)}',
    ]);

    if (weekendTxns > 0 && weekdayTxns > 0) {
      final weekdayDays = days > 7
          ? (days * 5 / 7).round()
          : byWeekday.keys.where((d) => d < 6).length;
      final weekendDays = days > 7
          ? (days * 2 / 7).round()
          : byWeekday.keys.where((d) => d >= 6).length;
      final weekdayAvg = weekdayDays > 0 ? weekdaySpend / weekdayDays : 0.0;
      final weekendAvg = weekendDays > 0 ? weekendSpend / weekendDays : 0.0;
      if (weekendAvg > weekdayAvg * 1.2) {
        final pctMore = ((weekendAvg / weekdayAvg - 1) * 100).round();
        lines.add('• Weekends run $pctMore% higher per day '
            '(${m(weekendAvg)} vs ${m(weekdayAvg)})');
      } else {
        lines.add('• Weekdays ${m(weekdayAvg)} a day, '
            'weekends ${m(weekendAvg)}');
      }
    }

    if (noSpendDays > 0) {
      lines.add('• $noSpendDays no-spend '
          'day${noSpendDays == 1 ? '' : 's'} out of $days');
    } else {
      lines.add('• Money went out every day this period');
    }

    // ── Personalised Financial Advice ──
    final tips = <String>[];

    // Tip 1: Savings rate advice
    if (savingsRate != null) {
      if (savingsRate < 0) {
        tips.add('You\'re spending more than you earn. This is unsustainable '
            '— review your wants spending (${m(wantsTotal)}) and find '
            '${m((total - income).abs())} to cut immediately.');
      } else if (savingsRate < 10) {
        tips.add('Your savings rate is only ${savingsRate.round()}%. '
            'Financial experts recommend saving at least 20% of income. '
            'Try to free up ${m(income * 0.2 - (income - total))} more '
            'from your lifestyle spending.');
      } else if (savingsRate < 20) {
        tips.add('You\'re saving ${savingsRate.round()}% — good, but aim '
            'for 20%+. Trimming ${m(income * 0.2 - (income - total))} from '
            'wants could get you there.');
      } else {
        tips.add('Excellent! You\'re saving ${savingsRate.round()}% of your '
            'income — that\'s above the recommended 20%. Keep it up!');
      }
    }

    // Tip 2: Needs/wants balance
    if (wantsPct > 40) {
      tips.add('$wantsPct% of spending goes to wants — a financial '
          'planner would suggest keeping this under 30%. Consider reviewing '
          '${_categoryName(categories, topCategory.key)} and similar '
          'discretionary categories.');
    } else if (wantsPct <= 30 && total > 0) {
      tips.add('Your needs/wants balance looks healthy at $needsPct/$wantsPct '
          '— well within the recommended 50/30 guideline.');
    }

    // Tip 3: Weekend spending
    if (weekendTxns > 0 && weekdayTxns > 0) {
      final weekdayDayCount = days > 7
          ? (days * 5 / 7).round()
          : byWeekday.keys.where((d) => d < 6).length;
      final weekendDayCount = days > 7
          ? (days * 2 / 7).round()
          : byWeekday.keys.where((d) => d >= 6).length;
      if (weekendDayCount > 0 && weekdayDayCount > 0) {
        final weekendAvgD = weekendSpend / weekendDayCount;
        final weekdayAvgD = weekdaySpend / weekdayDayCount;
        if (weekendAvgD > weekdayAvgD * 1.5) {
          tips.add('Weekend spending is significantly higher. Try setting '
              'a weekend budget of ${m(weekdayAvgD * 1.2)} per day — this '
              'alone could save you ${m((weekendAvgD - weekdayAvgD * 1.2) * weekendDayCount)} '
              'over this period.');
        }
      }
    }

    // Tip 4: No-spend days
    if (noSpendDays == 0 && days >= 7) {
      tips.add('Try adding 1–2 no-spend days per week. Even small breaks '
          'from spending build mindful money habits and could save you '
          '${m(perDay * 2)}/week.');
    }

    // Tip 5: High-frequency small purchases
    if (mostFrequent.value >= 5 && avgTransaction < total * 0.05) {
      final catName = _categoryName(categories, mostFrequent.key);
      tips.add('You made ${mostFrequent.value} $catName transactions — '
          'small, frequent purchases add up fast. Consider batching or '
          'setting a weekly $catName budget.');
    }

    // Tip 6: Top category concentration
    if (topCatPct >= 50) {
      tips.add('${_categoryName(categories, topCategory.key)} alone '
          'accounts for $topCatPct% of all spending. Diversifying could '
          'reduce risk of overspending in this area.');
    }

    // Budget-grounded advice leads: it names the user's own limits and
    // last month's figures, so it is always more useful than habit heuristics.
    // Budget-grounded advice first, then habit heuristics, capped: a page of
    // suggestions gets skimmed and none of them get acted on.
    final allTips = [...groundedAdvice, ...tips].take(4).toList();
    if (allTips.isNotEmpty) {
      lines.add('');
      lines.add('**Suggestions**');
      // Numbered rather than one emoji per line: six different pictograms
      // down the page reads as decoration, not priority.
      for (var i = 0; i < allTips.length; i++) {
        lines.add('${i + 1}. ${allTips[i]}');
      }
    }

    return lines.join('\n');
  }

  /// Whether a category is a commitment rather than discretionary spending.
  ///
  /// Matched on keywords rather than exact names, because a user's category
  /// is "House Loan" or "Car Loan", not "Loan EMI" — under exact matching
  /// those fell through to "wants", which had the assistant describing a
  /// mortgage as discretionary and inviting the user to trim it.
  ///
  /// A recurring transaction is treated as a commitment regardless of name:
  /// a monthly obligation the user has already signed up to is not a want,
  /// whatever the category is called.
  static const List<String> _essentialKeywords = [
    'rent', 'loan', 'emi', 'mortgage', 'insurance', 'premium',
    'grocer', 'food', 'diet', 'utilit', 'electric', 'water', 'gas bill',
    'bill', 'internet', 'phone', 'mobile', 'transport', 'transit', 'fuel',
    'petrol', 'commute', 'medical', 'health', 'medicine', 'pharmacy',
    'doctor', 'education', 'school', 'tuition', 'fees', 'childcare',
    'daycare', 'debt', 'tax',
  ];

  bool _isEssential(String categoryName, Transaction transaction) {
    if (transaction.isRecurring) return true;
    final name = categoryName.toLowerCase();
    return _essentialKeywords.any(name.contains);
  }

  String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(weekday - 1).clamp(0, 6)];
  }

  String _categorySpending(
    List<Transaction> transactions,
    List<Category> categories,
    AiSummaryRequest request,
    String currencySymbol,
    String currencyCode,
  ) {
    final categoryId = request.categoryId;
    if (categoryId == null) {
      return _topCategory(
        transactions,
        categories,
        request,
        currencySymbol,
        currencyCode,
      );
    }

    final total = transactions
        .where((transaction) =>
            transaction.isExpense && transaction.categoryId == categoryId)
        .fold(0.0, (sum, t) => sum + _amt(t));
    final categoryName = _categoryName(categories, categoryId);
    return 'You spent ${_money(total, currencySymbol, currencyCode)} on $categoryName ${_periodText(request)}.';
  }

  String _topCategory(
    List<Transaction> transactions,
    List<Category> categories,
    AiSummaryRequest request,
    String currencySymbol,
    String currencyCode,
  ) {
    final totals = <int, double>{};
    for (final transaction in transactions) {
      if (!transaction.isExpense) continue;
      totals[transaction.categoryId] =
          (totals[transaction.categoryId] ?? 0) + _amt(transaction);
    }

    if (totals.isEmpty) {
      return '🎉 No expenses found ${_periodText(request)} — nothing to rank!';
    }

    final top = totals.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    return '🏆 Your top spending category was ${_categoryName(categories, top.key)} at ${_money(top.value, currencySymbol, currencyCode)} ${_periodText(request)}.';
  }

  /// Builds a "🥇 Food — ₹2,100 (39%)" style top-3 list for spending answers.
  String _topCategoryBreakdown(
    List<Transaction> expenses,
    List<Category> categories,
    double total,
    String currencySymbol,
    String currencyCode,
  ) {
    if (total <= 0) return '';

    final totals = <int, double>{};
    for (final transaction in expenses) {
      totals[transaction.categoryId] =
          (totals[transaction.categoryId] ?? 0) + _amt(transaction);
    }
    if (totals.length < 2) return '';

    final ranked = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const medals = ['🥇', '🥈', '🥉'];

    final lines = <String>['**Top categories**'];
    for (var i = 0; i < ranked.length && i < 3; i++) {
      final entry = ranked[i];
      final percent = (entry.value / total * 100).round();
      lines.add(
        '${medals[i]} ${_categoryName(categories, entry.key)} — '
        '${_money(entry.value, currencySymbol, currencyCode)} ($percent%)',
      );
    }
    return lines.join('\n');
  }

  String _formatUpcoming(
    List<Transaction> all,
    String currencySymbol,
    String currencyCode,
  ) {
    final transactions = all.where((t) => !t.isTransfer).toList();
    if (transactions.isEmpty) {
      return '✨ Nothing recurring left this month — all clear!';
    }

    // Upcoming recurring entries include income as well as expenses, so the
    // two are totalled separately — netting them would be meaningless.
    final due = transactions.where((t) => t.isExpense).toList();
    final incoming = transactions.where((t) => !t.isExpense).toList();
    final dueTotal = due.fold(0.0, (sum, t) => sum + _amt(t));
    final incomingTotal = incoming.fold(0.0, (sum, t) => sum + _amt(t));

    final sorted = List<Transaction>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    final headline = <String>[];
    if (due.isNotEmpty) {
      headline.add('${due.length} payment${due.length == 1 ? '' : 's'} '
          'totaling ${_money(dueTotal, currencySymbol, currencyCode)}');
    }
    if (incoming.isNotEmpty) {
      headline.add('${incoming.length} income '
          'entr${incoming.length == 1 ? 'y' : 'ies'} totaling '
          '${_money(incomingTotal, currencySymbol, currencyCode)}');
    }

    final lines = <String>[
      '📅 Still to come this month: ${headline.join(' and ')}:',
    ];
    for (final transaction in sorted.take(4)) {
      lines.add(
        '• ${transaction.title} — '
        '${transaction.isExpense ? '-' : '+'}'
        '${_money(_amt(transaction), currencySymbol, currencyCode)} '
        'on ${UtilityFunction.formatDate(transaction.date)}',
      );
    }
    if (sorted.length > 4) {
      lines.add('…and ${sorted.length - 4} more.');
    }
    return lines.join('\n');
  }

  /// "today", "in September", "this week" — the way the user asked, not a
  /// pair of ISO-ish dates.
  String _periodText(AiSummaryRequest request) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final s = request.startDate;
    final e = request.endDate;
    bool same(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    if (same(s, e)) {
      if (same(s, today)) return 'today';
      if (same(s, today.subtract(const Duration(days: 1)))) return 'yesterday';
      return 'on ${DateFormat('EEE d MMM').format(s)}';
    }
    if (s.day == 1 && same(e, BudgetPeriod.endOfMonth(s))) {
      final month = DateFormat(s.year == now.year ? 'MMMM' : 'MMMM yyyy');
      return 'in ${month.format(s)}';
    }
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    if (same(s, weekStart) && same(e, today)) return 'this week';
    if (same(s, weekStart.subtract(const Duration(days: 7))) &&
        same(e, weekStart.subtract(const Duration(days: 1)))) {
      return 'last week';
    }
    if (s.month == 1 && s.day == 1 && s.year == now.year && same(e, today)) {
      return 'this year';
    }
    if (s.year < 2001) return 'so far';
    final fmt = DateFormat('d MMM');
    return 'from ${fmt.format(s)} to ${fmt.format(e)}';
  }

  String _money(double amount, String symbol, String code) {
    return UtilityFunction.addCommaWithSign(
      amount,
      currencySymbol: symbol,
      currencyCode: code,
    );
  }

  String _categoryName(List<Category> categories, int id) {
    for (final category in categories) {
      if (category.id == id) return category.name;
    }
    return 'Unknown Category';
  }
}
