import '../models/transaction.dart';

enum AiIntentType {
  addTransaction,
  summaryRequest,
  unsupported,
}

enum AiSummaryMetric {
  totalSpending,
  totalIncome,
  netBalance,
  categorySpending,
  topCategory,
  upcomingRecurring,
}

class AiIntent {
  final AiIntentType type;
  final double confidence;
  final AiTransactionDraft? transaction;
  final AiSummaryRequest? summaryRequest;
  final String message;

  const AiIntent({
    required this.type,
    required this.confidence,
    required this.message,
    this.transaction,
    this.summaryRequest,
  });

  factory AiIntent.fromJson(Map<String, dynamic> json) {
    final intent = json['intent'] as String? ?? 'unsupported';
    final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.0;
    final message = json['message'] as String? ??
        'I can help with adding transactions and basic spending summaries.';

    switch (intent) {
      case 'add_transaction':
        final transactionJson = json['transaction'];
        if (transactionJson is! Map<String, dynamic>) {
          return AiIntent.unsupported(message);
        }
        return AiIntent(
          type: AiIntentType.addTransaction,
          confidence: confidence,
          message: message,
          transaction: AiTransactionDraft.fromJson(transactionJson),
        );
      case 'summary_request':
        final summaryJson = json['summary'];
        if (summaryJson is! Map<String, dynamic>) {
          return AiIntent.unsupported(message);
        }
        return AiIntent(
          type: AiIntentType.summaryRequest,
          confidence: confidence,
          message: message,
          summaryRequest: AiSummaryRequest.fromJson(summaryJson),
        );
      default:
        return AiIntent.unsupported(message);
    }
  }

  factory AiIntent.unsupported([String? message]) {
    return AiIntent(
      type: AiIntentType.unsupported,
      confidence: 0,
      message: message ??
          'I can help with adding transactions and basic spending summaries.',
    );
  }
}

class AiTransactionDraft {
  final String title;
  final double amount;
  final bool isExpense;
  final int? categoryId;
  final int? accountId;
  final DateTime date;
  final bool isRecurring;
  final bool needsCategoryReview;
  final bool needsAccountReview;

  const AiTransactionDraft({
    required this.title,
    required this.amount,
    required this.isExpense,
    required this.date,
    this.categoryId,
    this.accountId,
    this.isRecurring = false,
    this.needsCategoryReview = false,
    this.needsAccountReview = false,
  });

  factory AiTransactionDraft.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] as num?)?.toDouble();
    // toLocal: a trailing Z or offset would otherwise parse as UTC and can
    // land an evening entry on the next day.
    final date = DateTime.tryParse(json['date'] as String? ?? '')?.toLocal();
    if (amount == null || amount <= 0 || date == null) {
      throw const FormatException('Invalid AI transaction draft');
    }

    return AiTransactionDraft(
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'AI Transaction',
      amount: amount,
      isExpense: json['isExpense'] as bool? ?? true,
      categoryId: (json['categoryId'] as num?)?.toInt(),
      accountId: (json['accountId'] as num?)?.toInt(),
      date: date,
      isRecurring: json['isRecurring'] as bool? ?? false,
      needsCategoryReview: json['needsCategoryReview'] as bool? ?? false,
      needsAccountReview: json['needsAccountReview'] as bool? ?? false,
    );
  }

  AiTransactionDraft withFallbacks({
    required int categoryId,
    required int accountId,
  }) {
    return AiTransactionDraft(
      title: title,
      amount: amount,
      isExpense: isExpense,
      categoryId: this.categoryId ?? categoryId,
      accountId: this.accountId ?? accountId,
      date: date,
      isRecurring: isRecurring,
      needsCategoryReview: needsCategoryReview || this.categoryId == null,
      needsAccountReview: needsAccountReview || this.accountId == null,
    );
  }

  AiTransactionDraft copyWith({
    String? title,
    double? amount,
    bool? isExpense,
    int? categoryId,
    int? accountId,
    DateTime? date,
    bool? isRecurring,
    bool? needsCategoryReview,
    bool? needsAccountReview,
  }) {
    return AiTransactionDraft(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      isExpense: isExpense ?? this.isExpense,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      isRecurring: isRecurring ?? this.isRecurring,
      needsCategoryReview: needsCategoryReview ?? this.needsCategoryReview,
      needsAccountReview: needsAccountReview ?? this.needsAccountReview,
    );
  }

  Transaction toTransaction() {
    if (categoryId == null || accountId == null) {
      throw StateError('Transaction draft is missing category or account');
    }

    return Transaction.createNew(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      categoryId: categoryId!,
      accountId: accountId!,
      date: date,
      isExpense: isExpense,
      isRecurring: isRecurring,
    );
  }
}

class AiSummaryRequest {
  final AiSummaryMetric metric;
  final DateTime startDate;
  final DateTime endDate;
  final int? categoryId;

  const AiSummaryRequest({
    required this.metric,
    required this.startDate,
    required this.endDate,
    this.categoryId,
  });

  factory AiSummaryRequest.fromJson(Map<String, dynamic> json) {
    final startDate = DateTime.tryParse(json['startDate'] as String? ?? '')?.toLocal();
    final endDate = DateTime.tryParse(json['endDate'] as String? ?? '')?.toLocal();

    if (startDate == null || endDate == null) {
      throw const FormatException('Invalid AI summary date range');
    }

    return AiSummaryRequest(
      metric: _metricFromString(json['metric'] as String?),
      startDate: startDate,
      endDate: endDate,
      categoryId: (json['categoryId'] as num?)?.toInt(),
    );
  }

  static AiSummaryMetric _metricFromString(String? value) {
    switch (value) {
      case 'total_spending':
        return AiSummaryMetric.totalSpending;
      case 'total_income':
        return AiSummaryMetric.totalIncome;
      case 'net_balance':
        return AiSummaryMetric.netBalance;
      case 'category_spending':
        return AiSummaryMetric.categorySpending;
      case 'top_category':
        return AiSummaryMetric.topCategory;
      case 'upcoming_recurring':
        return AiSummaryMetric.upcomingRecurring;
      default:
        return AiSummaryMetric.totalSpending;
    }
  }
}
