import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../db/account_db_helper.dart';
import '../db/category_db_helper.dart';
import '../db/transaction_db_helper.dart';
import '../models/transaction.dart';
import '../utilities/constants.dart';
import '../utilities/id_generator.dart';

class ImportResult {
  final int imported;
  final int skippedDuplicates;
  final int failed;
  final List<String> errors;

  const ImportResult({
    required this.imported,
    required this.skippedDuplicates,
    required this.failed,
    required this.errors,
  });
}

/// Imports transactions from a CSV file. Round-trips this app's own export
/// format and tolerates reordered columns and common third-party layouts.
class ImportService {
  static final ImportService _instance = ImportService._internal();
  factory ImportService() => _instance;
  ImportService._internal();

  Future<ImportResult> importTransactionsCsv(String filePath) async {
    final errors = <String>[];
    int imported = 0;
    int skipped = 0;
    int failed = 0;

    final rawFile = File(filePath);
    if (!await rawFile.exists()) {
      return const ImportResult(
        imported: 0,
        skippedDuplicates: 0,
        failed: 0,
        errors: ['File not found'],
      );
    }

    // Normalize Excel CRLF so the CSV parser sees consistent line endings.
    final raw = (await rawFile.readAsString()).replaceAll('\r\n', '\n');
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(raw);

    if (rows.isEmpty) {
      return const ImportResult(
        imported: 0,
        skippedDuplicates: 0,
        failed: 0,
        errors: ['File is empty'],
      );
    }

    // Map columns by header NAME (case-insensitive), so reordered files work.
    final header = rows.first.map((c) => c.toString().trim().toLowerCase()).toList();
    int col(List<String> names) {
      for (final n in names) {
        final i = header.indexOf(n);
        if (i != -1) return i;
      }
      return -1;
    }

    final dateCol = col(['date']);
    final amountCol = col(['amount']);
    final titleCol = col(['title', 'note', 'notes', 'description']);
    final typeCol = col(['type']);
    final categoryCol = col(['category']);
    final accountCol = col(['account']);

    final missing = <String>[];
    if (dateCol == -1) missing.add('Date');
    if (amountCol == -1) missing.add('Amount');
    if (missing.isNotEmpty) {
      return ImportResult(
        imported: 0,
        skippedDuplicates: 0,
        failed: 0,
        errors: ['Missing required column(s): ${missing.join(', ')}'],
      );
    }

    // Preload lookups ONCE (no per-row DB queries).
    final categoryRows = await DBHelper().getAllCategories();
    // name(lower)+isExpense -> id
    final categoryByKey = <String, int>{};
    for (final r in categoryRows) {
      final name = (r['name'] as String?)?.trim().toLowerCase();
      final isExp = (r['isExpense'] as int? ?? 1) == 1;
      final id = r['id'] as int?;
      if (name != null && id != null) categoryByKey['$name|$isExp'] = id;
    }

    final accounts = await AccountDBHelper().getAllAccounts();
    final accountByName = <String, int>{
      for (final a in accounts)
        if (a.id != null) a.name.trim().toLowerCase(): a.id!,
    };

    // Existing keys for duplicate detection: isoDate|amount|title(lower).
    final existing = await TransactionDBHelper().getTransactions();
    final existingKeys = <String>{
      for (final t in existing) _dupKey(t.date, t.amount, t.title),
    };

    final toInsert = <Transaction>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      try {
        String cell(int c) =>
            (c >= 0 && c < row.length) ? row[c].toString().trim() : '';

        final rawDate = cell(dateCol);
        final date = _parseDate(rawDate);
        if (date == null) {
          throw 'unrecognized date "$rawDate"';
        }

        final rawAmount = cell(amountCol);
        final cleaned = rawAmount.replaceAll(RegExp(r'[^\d.\-]'), '');
        final parsedAmount = double.tryParse(cleaned);
        if (parsedAmount == null || parsedAmount == 0) {
          throw 'invalid amount "$rawAmount"';
        }

        // Determine expense/income: explicit type column wins; otherwise a
        // negative amount means an expense.
        bool isExpense;
        final typeVal = cell(typeCol).toLowerCase();
        if (typeVal == 'expense') {
          isExpense = true;
        } else if (typeVal == 'income') {
          isExpense = false;
        } else {
          isExpense = parsedAmount < 0;
        }
        final amount = parsedAmount.abs();

        final title = cell(titleCol);

        final key = _dupKey(date, amount, title);
        if (existingKeys.contains(key)) {
          skipped++;
          continue;
        }
        existingKeys.add(key); // also dedup within the file itself

        final categoryName = cell(categoryCol);
        final categoryId =
            await _resolveCategory(categoryName, isExpense, categoryByKey);

        final accountName = cell(accountCol).toLowerCase();
        final accountId = accountByName[accountName] ?? 1;

        toInsert.add(Transaction.createNew(
          id: newId(),
          title: title,
          amount: amount,
          categoryId: categoryId,
          accountId: accountId,
          date: date,
          isExpense: isExpense,
          isRecurring: false, // imported history must never spawn future bills
        ));
      } catch (e) {
        failed++;
        errors.add('Row ${i + 1}: $e');
      }
    }

    if (toInsert.isNotEmpty) {
      await TransactionDBHelper().insertTransactionsBatch(toInsert);
      imported = toInsert.length;
    }

    return ImportResult(
      imported: imported,
      skippedDuplicates: skipped,
      failed: failed,
      errors: errors,
    );
  }

  String _dupKey(DateTime date, double amount, String title) {
    final iso = DateFormat('yyyy-MM-dd').format(date);
    return '$iso|${amount.toStringAsFixed(2)}|${title.trim().toLowerCase()}';
  }

  DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    // ISO first.
    final iso = DateTime.tryParse(raw);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    // Then common display formats. DateFormat.parse THROWS, so guard each.
    for (final fmt in const [
      'MMM dd, yyyy',
      'MMM d, yyyy',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'yyyy/MM/dd',
    ]) {
      try {
        final d = DateFormat(fmt).parseStrict(raw);
        return DateTime(d.year, d.month, d.day);
      } catch (_) {
        // try next format
      }
    }
    return null;
  }

  /// Case-insensitive category match; creates the category once (cached) if
  /// it doesn't exist, so 500 rows of a new category make ONE row.
  Future<int> _resolveCategory(
    String name,
    bool isExpense,
    Map<String, int> cache,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return isExpense ? defaultExpenseCat : defaultIncomeCat;
    }
    final key = '${trimmed.toLowerCase()}|$isExpense';
    final hit = cache[key];
    if (hit != null) return hit;

    final newCatId = await DBHelper().insertCategory(
      trimmed,
      'assets/categories/other.png',
      isExpense,
    );
    cache[key] = newCatId;
    return newCatId;
  }
}
