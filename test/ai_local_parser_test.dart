import 'package:coin_manager/models/ai_intent.dart';
import 'package:coin_manager/models/category.dart';
import 'package:coin_manager/services/ai_local_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
