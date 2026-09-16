import 'package:coin_manager/models/account.dart';
import 'package:coin_manager/models/ai_intent.dart';
import 'package:coin_manager/models/category.dart';
import 'package:coin_manager/services/ai_local_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _adviceTriggers();
  _comparisonTriggers();
  _smarterParsing();

  final parser = AiLocalParser();
  final categories = [
    Category(id: 1, name: 'Food', icon: 'food.png', isExpense: true),
    Category(id: 2, name: 'Transport', icon: 'bus.png', isExpense: true),
    Category(id: 3, name: 'Salary', icon: 'cash.png', isExpense: false),
  ];

  AiIntent? parse(String message) =>
      parser.tryParse(message: message, categories: categories);

  group('add transaction', () {
    test('parses "add expense 200 coffee"', () {
      final intent = parse('add expense 200 coffee');
      expect(intent?.type, AiIntentType.addTransaction);
      expect(intent?.transaction?.amount, 200);
      expect(intent?.transaction?.title, 'Coffee');
      expect(intent?.transaction?.isExpense, isTrue);
    });

    test('parses "spent 50 on food yesterday" with category and date', () {
      final intent = parse('spent 50 on food yesterday');
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));
      expect(intent?.type, AiIntentType.addTransaction);
      expect(intent?.transaction?.categoryId, 1);
      expect(intent?.transaction?.date, yesterday);
    });

    test('parses short "coffee 4.50" style message', () {
      final intent = parse('coffee 4.50');
      expect(intent?.type, AiIntentType.addTransaction);
      expect(intent?.transaction?.amount, 4.50);
      expect(intent?.transaction?.title, 'Coffee');
    });

    test('parses income with comma amount', () {
      final intent = parse('received salary 1,20,000'.replaceAll(',', ''));
      expect(intent?.type, AiIntentType.addTransaction);
      expect(intent?.transaction?.isExpense, isFalse);
      expect(intent?.transaction?.categoryId, 3);
    });

    test('rejects long free-form message without a verb', () {
      expect(
        parse('I think maybe around 200 would be a fair guess overall'),
        isNull,
      );
    });
  });

  group('summaries', () {
    test('parses "how much did I spend this week?"', () {
      final intent = parse('how much did I spend this week?');
      expect(intent?.type, AiIntentType.summaryRequest);
      expect(intent?.summaryRequest?.metric, AiSummaryMetric.totalSpending);
    });

    group('spending habits', () {
      // Every phrase here also contains "spend"/"spending", which an earlier
      // branch would otherwise claim and answer with a bare total.
      for (final phrase in const [
        'my spending habits',
        'what are my spending habits?',
        'show me my spending patterns',
        'any insights on my spending?',
        'what are my spending trends this month',
        'analyse my spending',
        'how am i doing this month?',
      ]) {
        test('"$phrase" resolves to spendingHabits', () {
          final intent = parse(phrase);
          expect(intent?.type, AiIntentType.summaryRequest);
          expect(
            intent?.summaryRequest?.metric,
            AiSummaryMetric.spendingHabits,
            reason: '"$phrase" was claimed by another metric',
          );
        });
      }

      test('a plain spending question is still a plain total', () {
        final intent = parse('how much did I spend this month?');
        expect(intent?.summaryRequest?.metric, AiSummaryMetric.totalSpending);
      });

      test('habits question still picks up the period', () {
        final intent = parse('my spending habits last month');
        final expected = DateTime.now().month == 1
            ? 12
            : DateTime.now().month - 1;
        expect(intent?.summaryRequest?.metric, AiSummaryMetric.spendingHabits);
        expect(intent?.summaryRequest?.startDate.month, expected);
      });
    });

    test('parses top category question', () {
      final intent = parse('what is my top spending category this month?');
      expect(intent?.summaryRequest?.metric, AiSummaryMetric.topCategory);
    });

    test('parses category spending question', () {
      final intent = parse('how much did I spend on transport last month?');
      expect(intent?.summaryRequest?.metric, AiSummaryMetric.categorySpending);
      expect(intent?.summaryRequest?.categoryId, 2);
      final now = DateTime.now();
      expect(
        intent?.summaryRequest?.startDate,
        DateTime(now.year, now.month - 1, 1),
      );
    });

    test('parses net balance question', () {
      final intent = parse('what is my net balance this month?');
      expect(intent?.summaryRequest?.metric, AiSummaryMetric.netBalance);
    });

    test('parses upcoming recurring question', () {
      final intent = parse('show my upcoming recurring payments');
      expect(
        intent?.summaryRequest?.metric,
        AiSummaryMetric.upcomingRecurring,
      );
    });

    test('returns null for unrelated chatter', () {
      expect(parse('tell me a joke'), isNull);
    });
  });

  group('trust: the amount is the price, not the count', () {
    test('"2 coffees 300" logs 300, not 2', () {
      final t = parse('2 coffees 300')?.transaction;
      expect(t?.amount, 300);
    });

    test('a single amount is still read as-is', () {
      expect(parse('coffee 150')?.transaction?.amount, 150);
    });

    test('multipliers are compared after expanding', () {
      expect(parse('2 laptops 1.2 lakh')?.transaction?.amount, 120000);
    });

    test('a date is still not an amount', () {
      final t = parse('rent 25000 on the 1st')?.transaction;
      expect(t?.amount, 25000);
    });
  });

  group('trust: declines instead of guessing', () {
    AiIntent? out(String m) => parse(m);

    test('"change that to 200" does not become a new 200 expense', () {
      final intent = out('change that to 200');
      expect(intent?.type, AiIntentType.editTransaction);
      expect(intent?.transaction, isNull);
      // A bare pronoun means whatever was saved last, not a search.
      expect(intent?.edit?.term, isNull);
      expect(intent?.edit?.newAmount, 200);
      expect(intent?.edit?.isDelete, isFalse);
    });

    test('deleting by description targets that description', () {
      final intent = out('delete the coffee I added yesterday');
      expect(intent?.type, AiIntentType.editTransaction);
      expect(intent?.edit?.isDelete, isTrue);
      expect(intent?.edit?.term, 'coffee');
    });

    test('a term with no date in it survives intact', () {
      // The period token is empty here; stripping it must be a no-op.
      expect(out('delete monthly income')?.edit?.term, 'monthly income');
      expect(out('delete spotify')?.edit?.term, 'spotify');
    });

    test('a delete carrying an amount is an expense, not a deletion', () {
      final t = out('remove stains 200')?.transaction;
      expect(t?.amount, 200);
    });

    test('affordability is declined', () {
      expect(out('can i afford a 40000 phone')?.type,
          AiIntentType.unsupported);
    });

    test('a bare yes with nothing pending never reaches the cloud', () {
      final intent = out('yes');
      expect(intent, isNotNull);
      expect(intent?.type, AiIntentType.unsupported);
    });

    test('a merchant with no amount asks for the amount', () {
      final intent = out('starbucks');
      expect(intent?.type, AiIntentType.unsupported);
      expect(intent?.message, contains('How much'));
    });

    test('"how much on food this month" is answered, not sent to the cloud',
        () {
      final r = out('how much on food this month')?.summaryRequest;
      expect(r?.metric, AiSummaryMetric.categorySpending);
      expect(r?.categoryId, 1);
    });

    test('"undo" is still a real undo', () {
      expect(out('undo')?.type, AiIntentType.undo);
    });

    test('"change my budget to 5000" is about budgets, not a transaction', () {
      final intent = out('change my budget to 5000');
      expect(intent?.type, AiIntentType.unsupported);
      expect(intent?.message, contains('Budget tab'));
    });

    test('setting a budget is declined', () {
      expect(out('set a budget of 5000 for food')?.type,
          AiIntentType.unsupported);
    });

    test('"how\'s my budget" still answers', () {
      expect(out('how\'s my budget')?.type, AiIntentType.budgetQuery);
    });

    test('reminders are declined', () {
      expect(out('remind me to pay rent on the 1st')?.type,
          AiIntentType.unsupported);
    });

    test('an average is declined rather than answered with one month', () {
      expect(out('what is my average monthly spend')?.type,
          AiIntentType.unsupported);
    });

    test('a normal expense starting with a verb is still logged', () {
      final t = out('change the tyre 5000')?.transaction;
      expect(t?.amount, 5000);
    });
  });

  group('trust: answers the tense that was asked', () {
    test('"what will I have left" is an allowance question', () {
      expect(
        parse('how much will I have left at the end of the month')?.type,
        AiIntentType.budgetQuery,
      );
    });

    test('"how much did I save this year" is a net balance, not a fallthrough',
        () {
      final r = parse('how much did I save this year')?.summaryRequest;
      expect(r?.metric, AiSummaryMetric.netBalance);
    });
  });

}

/// Asking for advice in plain language must reach the advisor, not fall
/// through as unsupported.
void _adviceTriggers() {
  final parser = AiLocalParser();
  final categories = [
    Category(id: 1, name: 'Food', icon: 'food.png', isExpense: true),
  ];

  group('advice phrasings', () {
    const asks = [
      'any suggestions?',
      'how can I save money',
      'give me some advice',
      'what do you recommend',
      'any tips for me',
      'where can I cut back',
      'help me budget better',
      'how do I spend less',
    ];

    for (final ask in asks) {
      test('"$ask" asks for spending advice', () {
        final intent =
            parser.tryParse(message: ask, categories: categories);
        expect(intent?.type, AiIntentType.summaryRequest,
            reason: '"$ask" should be understood as a request for advice');
        expect(intent?.summaryRequest?.metric, AiSummaryMetric.spendingHabits);
      });
    }
  });
}

/// The second-generation parser: multipliers, everyday words, accounts,
/// richer dates, lookups, arithmetic, and period-only follow-ups.
void _smarterParsing() {
  final parser = AiLocalParser();
  final categories = [
    Category(id: 1, name: 'Food', icon: 'food.png', isExpense: true),
    Category(id: 2, name: 'Transit', icon: 'bus.png', isExpense: true),
    Category(id: 3, name: 'Salary', icon: 'cash.png', isExpense: false),
  ];
  final accounts = [
    Account(
      id: 7,
      name: 'Cash',
      icon: 'wallet',
      color: '#4CAF50',
      isDefault: true,
      createdOn: DateTime(2026),
      modifiedOn: DateTime(2026),
    ),
  ];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  AiIntent? parse(String message, {AiSummaryRequest? previous}) =>
      parser.tryParse(
        message: message,
        categories: categories,
        accounts: accounts,
        previous: previous,
      );

  group('smarter add', () {
    test('k multiplier, everyday word, account and weekday date', () {
      final intent = parse('spent 1.5k on groceries last friday from cash');
      final t = intent?.transaction;
      expect(intent?.type, AiIntentType.addTransaction);
      expect(t?.amount, 1500);
      expect(t?.categoryId, 1, reason: 'groceries should land in Food');
      expect(t?.accountId, 7);
      expect(t?.date.weekday, DateTime.friday);
      expect(t?.date.isBefore(today), isTrue);
      expect(t?.title, 'Groceries');
    });

    test('"coffee 200" is Food without naming the category', () {
      expect(parse('coffee 200')?.transaction?.categoryId, 1);
    });

    test('"paid 300 for uber" is Transit', () {
      final t = parse('paid 300 for uber')?.transaction;
      expect(t?.categoryId, 2);
      expect(t?.title, 'Uber');
    });

    test('currency prefix and "days ago"', () {
      final t = parse('rs.250 lunch 3 days ago')?.transaction;
      expect(t?.amount, 250);
      expect(t?.date, today.subtract(const Duration(days: 3)));
      expect(t?.title, 'Lunch');
    });

    test('"on the 5th" is a date, not an amount', () {
      final t = parse('paid 900 rent on the 5th')?.transaction;
      expect(t?.amount, 900);
      expect(t?.date.day, 5);
    });
  });

  group('lookups', () {
    test('"find netflix" searches all history', () {
      final r = parse('find netflix')?.summaryRequest;
      expect(r?.metric, AiSummaryMetric.searchTransactions);
      expect(r?.searchTerm, 'netflix');
      expect(r?.startDate.year, 2000);
    });

    test('"when did I last pay rent?" searches for rent', () {
      final r = parse('when did I last pay rent?')?.summaryRequest;
      expect(r?.metric, AiSummaryMetric.searchTransactions);
      expect(r?.searchTerm, 'rent');
    });

    test('biggest expense', () {
      expect(parse('biggest expense this month')?.summaryRequest?.metric,
          AiSummaryMetric.largestExpense);
      expect(parse("what's my biggest expense?")?.summaryRequest?.metric,
          AiSummaryMetric.largestExpense);
    });

    test('top category still wins over "biggest"', () {
      expect(parse('biggest category this month')?.summaryRequest?.metric,
          AiSummaryMetric.topCategory);
    });

    test('recent transactions', () {
      expect(parse('show recent transactions')?.summaryRequest?.metric,
          AiSummaryMetric.recentTransactions);
      final r = parse('what did I spend on yesterday?')?.summaryRequest;
      expect(r?.metric, AiSummaryMetric.recentTransactions);
      expect(r?.startDate, today.subtract(const Duration(days: 1)));
    });

    test('upcoming bills are not a search', () {
      expect(parse('show my upcoming recurring payments')?.summaryRequest?.metric,
          AiSummaryMetric.upcomingRecurring);
    });

    test('the user\'s own category name is a category question', () {
      final r = parse('how much did I spend on food this month')?.summaryRequest;
      expect(r?.metric, AiSummaryMetric.categorySpending);
      expect(r?.categoryId, 1);
    });

    // Answering "spend on coffee" with the whole Food total is the right
    // number for a question nobody asked. A merchant or everyday word is
    // searched for instead, so the answer is about the word they used.
    test('a merchant word is searched, not widened to its category', () {
      final r = parse('how much did I spend on coffee this month')?.summaryRequest;
      expect(r?.metric, AiSummaryMetric.searchTransactions);
      expect(r?.searchTerm, 'coffee');
      expect(r?.categoryId, isNull);
    });

    test('a merchant name keeps the asked-for period', () {
      final r = parse('how much did I spend at swiggy this year')?.summaryRequest;
      expect(r?.metric, AiSummaryMetric.searchTransactions);
      expect(r?.searchTerm, 'swiggy');
      expect(r?.startDate.month, 1);
    });

    test('named month period', () {
      final r = parse('how much did I spend in january')?.summaryRequest;
      expect(r?.startDate.month, 1);
      expect(r?.endDate.day, 31);
    });
  });

  group('simple commands', () {
    test('undo / help / greeting', () {
      expect(parse('undo')?.type, AiIntentType.undo);
      expect(parse('Undo that!')?.type, AiIntentType.undo);
      expect(parse('help')?.type, AiIntentType.help);
      expect(parse('what can you do?')?.type, AiIntentType.help);
      expect(parse('hi')?.type, AiIntentType.smallTalk);
      expect(parse('thanks!')?.type, AiIntentType.smallTalk);
    });

    test('arithmetic', () {
      expect(parse("what's 15% of 2400")?.message, '360');
      expect(parse('2400/3')?.message, '800');
      expect(parse('199*12')?.message, '2388');
      expect(parse('200')?.type, isNot(AiIntentType.calculation));
    });

    test('daily allowance is a budget question', () {
      expect(parse('how much can I spend today?')?.type,
          AiIntentType.budgetQuery);
    });
  });

  group('follow-ups', () {
    final previous = AiSummaryRequest(
      metric: AiSummaryMetric.topCategory,
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month + 1, 0),
    );

    test('"and last month?" re-asks with the new period', () {
      final r = parse('and last month?', previous: previous)?.summaryRequest;
      expect(r?.metric, AiSummaryMetric.topCategory);
      expect(r?.startDate, DateTime(now.year, now.month - 1, 1));
    });

    test('"what about this week" too', () {
      final r = parse('what about this week', previous: previous)?.summaryRequest;
      expect(r?.metric, AiSummaryMetric.topCategory);
      expect(r?.endDate, today);
    });

    test('a period with other words is not a follow-up', () {
      final r = parse('income last month', previous: previous)?.summaryRequest;
      expect(r?.metric, isNot(AiSummaryMetric.topCategory));
    });

    test('nothing to follow up on', () {
      expect(parse('and last month?'), isNull);
    });
  });
}

/// Comparison phrasings must stay on-device; none of them carry a question
/// word, so they depend on their own gate.
void _comparisonTriggers() {
  final parser = AiLocalParser();
  final categories = [
    Category(id: 1, name: 'Food', icon: 'food.png', isExpense: true),
  ];

  group('comparison phrasings', () {
    for (final ask in const [
      'compare this month to last month',
      'am i spending more than last month',
      'this month vs last month',
      'month over month spending',
    ]) {
      test('"$ask" is a month comparison', () {
        final intent =
            parser.tryParse(message: ask, categories: categories);
        expect(intent?.summaryRequest?.metric,
            AiSummaryMetric.monthComparison,
            reason: '"$ask" should not fall through to the cloud');
      });
    }
  });
}
