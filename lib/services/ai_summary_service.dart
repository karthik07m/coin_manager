import '../db/transaction_db_helper.dart';
import '../models/ai_intent.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../utilities/functions.dart';

class AiSummaryService {
  final TransactionDBHelper _dbHelper;

  AiSummaryService({TransactionDBHelper? dbHelper})
      : _dbHelper = dbHelper ?? TransactionDBHelper();

  Future<String> buildSummary({
    required AiSummaryRequest request,
    required List<Category> categories,
    required String currencySymbol,
    required String currencyCode,
  }) async {
    if (request.metric == AiSummaryMetric.upcomingRecurring) {
      final upcoming = await _dbHelper.getAllUpcomingRecurringTransactions();
      return _formatUpcoming(upcoming, currencySymbol, currencyCode);
    }

    final transactions = await _dbHelper.getTransactionsByType(
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

    switch (request.metric) {
      case AiSummaryMetric.totalSpending:
        final expenses =
            transactions.where((transaction) => transaction.isExpense).toList();
        final total =
            expenses.fold(0.0, (sum, transaction) => sum + transaction.amount);
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
            .fold(0.0, (sum, transaction) => sum + transaction.amount);
        return '💰 Your income was ${_money(total, currencySymbol, currencyCode)} ${_periodText(request)}.';
      case AiSummaryMetric.netBalance:
        final income = transactions
            .where((transaction) => !transaction.isExpense)
            .fold(0.0, (sum, transaction) => sum + transaction.amount);
        final expenses = transactions
            .where((transaction) => transaction.isExpense)
            .fold(0.0, (sum, transaction) => sum + transaction.amount);
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
      case AiSummaryMetric.upcomingRecurring:
        throw StateError('Handled before loading period transactions');
    }
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
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
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
          (totals[transaction.categoryId] ?? 0) + transaction.amount;
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
          (totals[transaction.categoryId] ?? 0) + transaction.amount;
    }
    if (totals.length < 2) return '';

    final ranked = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const medals = ['🥇', '🥈', '🥉'];

    final lines = <String>['Top categories:'];
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
    List<Transaction> transactions,
    String currencySymbol,
    String currencyCode,
  ) {
    if (transactions.isEmpty) {
      return '✨ No upcoming recurring payments this month — all clear!';
    }

    final total = transactions.fold(
      0.0,
      (sum, transaction) => sum + transaction.amount,
    );
    final sorted = List<Transaction>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));
    final lines = <String>[
      '📅 You have ${transactions.length} upcoming recurring '
          'payment${transactions.length == 1 ? '' : 's'} totaling '
          '${_money(total, currencySymbol, currencyCode)}:',
    ];
    for (final transaction in sorted.take(4)) {
      lines.add(
        '• ${transaction.title} — '
        '${_money(transaction.amount, currencySymbol, currencyCode)} '
        'on ${UtilityFunction.formatDate(transaction.date)}',
      );
    }
    if (sorted.length > 4) {
      lines.add('…and ${sorted.length - 4} more.');
    }
    return lines.join('\n');
  }

  String _periodText(AiSummaryRequest request) {
    final start = UtilityFunction.formatDate(request.startDate);
    final end = UtilityFunction.formatDate(request.endDate);
    if (start == end) return 'on $start';
    return 'from $start to $end';
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
