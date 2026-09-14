import 'package:coin_manager/models/ai_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses add transaction intent', () {
    final intent = AiIntent.fromJson({
      'intent': 'add_transaction',
      'confidence': 0.92,
      'message': 'I found a lunch expense.',
      'transaction': {
        'title': 'Lunch',
        'amount': 25,
        'isExpense': true,
        'categoryId': 1,
        'accountId': 1,
        'date': '2026-06-16T12:00:00',
        'isRecurring': false,
      },
    });

    expect(intent.type, AiIntentType.addTransaction);
    expect(intent.transaction?.title, 'Lunch');
    expect(intent.transaction?.amount, 25);
    expect(intent.transaction?.categoryId, 1);
  });

  test('rejects malformed transaction draft', () {
    expect(
      () => AiIntent.fromJson({
        'intent': 'add_transaction',
        'transaction': {
          'title': 'Lunch',
          'amount': -5,
          'date': 'bad-date',
        },
      }),
      throwsFormatException,
    );
  });

  test('parses summary request intent', () {
    final intent = AiIntent.fromJson({
      'intent': 'summary_request',
      'confidence': 0.8,
      'message': 'Checking spending.',
      'summary': {
        'metric': 'total_spending',
        'startDate': '2026-06-01T00:00:00',
        'endDate': '2026-06-30T23:59:59',
      },
    });

    expect(intent.type, AiIntentType.summaryRequest);
    expect(intent.summaryRequest?.metric, AiSummaryMetric.totalSpending);
  });

  test('reads AI dates as local time, even with a trailing Z', () {
    // 01:08 UTC is still the previous evening west of Greenwich; parsed as
    // UTC it would date an evening expense tomorrow.
    final utc = DateTime.utc(2026, 9, 14, 1, 8);

    final draft = AiIntent.fromJson({
      'intent': 'add_transaction',
      'transaction': {
        'title': 'Auto rickshaw',
        'amount': 120,
        'isExpense': true,
        'date': '2026-09-14T01:08:00Z',
      },
    }).transaction!;
    expect(draft.date.isUtc, isFalse);
    expect(draft.date, utc.toLocal());

    final summary = AiIntent.fromJson({
      'intent': 'summary_request',
      'summary': {
        'metric': 'total_spending',
        'startDate': '2026-09-01T00:00:00',
        'endDate': '2026-09-14T01:08:00Z',
      },
    }).summaryRequest!;
    expect(summary.startDate, DateTime(2026, 9, 1));
    expect(summary.endDate.isUtc, isFalse);
    expect(summary.endDate, utc.toLocal());
  });
}
