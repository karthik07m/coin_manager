import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/account_db_helper.dart';
import '../db/category_db_helper.dart';
import '../db/transaction_db_helper.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';

class ExportResult {
  final String path;
  final String fileName;
  final int rowCount;

  const ExportResult({
    required this.path,
    required this.fileName,
    required this.rowCount,
  });
}

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  Future<ExportResult> createTransactionsCsvExport() async {
    final transactions = await TransactionDBHelper().getTransactions();
    final categories = await DBHelper().getAllCategories();
    final accounts = await AccountDBHelper().getAllAccounts();

    final categoryMap = {
      for (final item in categories)
        if (item['id'] != null) item['id'] as int: Category.fromMap(item),
    };
    final accountMap = {
      for (final account in accounts)
        if (account.id != null) account.id!: account,
    };

    final rows = <List<String>>[
      [
        'Date',
        'Time',
        'Type',
        'Title',
        'Category',
        'Account',
        'Amount',
        'Recurring',
        'Receipt Attached',
        'Created At',
        'Modified At',
        'Transaction ID',
      ],
      ...transactions.map(
        (transaction) => _transactionRow(
          transaction,
          categoryMap[transaction.categoryId],
          accountMap[transaction.accountId],
        ),
      ),
    ];

    final csv = rows.map(_csvRow).join('\n');
    final exportsDir = await _exportsDirectory();
    final fileName =
        'coinly_transactions_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File(path.join(exportsDir.path, fileName));
    await file.writeAsString(csv);

    return ExportResult(
      path: file.path,
      fileName: fileName,
      rowCount: transactions.length,
    );
  }

  Future<void> shareExport(ExportResult result) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(result.path)],
        text: 'Coinly Transactions Export - ${result.rowCount} rows',
      ),
    );
  }

  Future<Directory> _exportsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(path.join(appDir.path, 'exports'));
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    return exportsDir;
  }

  List<String> _transactionRow(
    Transaction transaction,
    Category? category,
    Account? account,
  ) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');
    final timestampFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return [
      dateFormat.format(transaction.date),
      timeFormat.format(transaction.date),
      transaction.isExpense ? 'Expense' : 'Income',
      transaction.title,
      category?.name ?? 'Unknown',
      account?.name ?? 'Unknown',
      transaction.amount.toStringAsFixed(2),
      transaction.isRecurring ? 'Yes' : 'No',
      transaction.receiptId == null || transaction.receiptId!.trim().isEmpty
          ? 'No'
          : 'Yes',
      timestampFormat.format(transaction.createdOn),
      timestampFormat.format(transaction.modifiedOn),
      transaction.id,
    ];
  }

  String _csvRow(List<String> values) {
    return values.map(_csvCell).join(',');
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }
}
