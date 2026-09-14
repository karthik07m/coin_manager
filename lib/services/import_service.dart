import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/account_db_helper.dart';
import '../db/category_db_helper.dart';
import '../db/transaction_db_helper.dart';
import '../models/account.dart';
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

    return _importRows(rows.map((row) => row.map((cell) => cell.toString()).toList()).toList());
  }

  Future<ImportResult> importTransactionsExcel(String filePath) async {
    final rawFile = File(filePath);
    if (!await rawFile.exists()) {
      return const ImportResult(
        imported: 0,
        skippedDuplicates: 0,
        failed: 0,
        errors: ['File not found'],
      );
    }

    final bytes = await rawFile.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final sheetName = excel.tables.keys.contains('Transactions')
        ? 'Transactions'
        : (excel.getDefaultSheet() ?? excel.tables.keys.first);
    final sheet = excel.tables[sheetName];

    if (sheet == null || sheet.rows.isEmpty) {
      return const ImportResult(
        imported: 0,
        skippedDuplicates: 0,
        failed: 0,
        errors: ['No data in Excel file'],
      );
    }

    final rows = <List<String>>[];
    for (final row in sheet.rows) {
      rows.add(row.map((cell) => _cellValueToString(cell?.value)).toList());
    }

    return _importRows(rows);
  }

  String _cellValueToString(CellValue? value) {
    if (value == null) return '';
    if (value is TextCellValue) return value.value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is DateCellValue) {
      return "${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}";
    }
    if (value is DateTimeCellValue) {
      return "${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour}:${value.minute}";
    }
    if (value is BoolCellValue) return value.value ? 'true' : 'false';
    return value.toString();
  }

  Future<ImportResult> _importRows(List<List<String>> rows) async {
    final errors = <String>[];
    int imported = 0;
    int skipped = 0;
    int failed = 0;

    if (rows.isEmpty) {
      return const ImportResult(
        imported: 0,
        skippedDuplicates: 0,
        failed: 0,
        errors: ['No data to import'],
      );
    }

    // Map columns by header NAME (case-insensitive), so reordered files work.
    final header = rows.first.map((c) => c.toString().trim().toLowerCase()).toList();
    int col(List<String> names) {
      for (final n in names) {
        final i = header.indexOf(n);
        if (i != -1) return i;
      }
      // Fallback: check if any header starts with the name, e.g., 'amount (usd)'
      for (final n in names) {
        for (int i = 0; i < header.length; i++) {
          if (header[i].startsWith(n)) return i;
        }
      }
      return -1;
    }

    final dateCol = col(['date']);
    final amountCol = col(['amount']);
    final titleCol = col(['title', 'note', 'notes', 'description']);
    final typeCol = col(['type']);
    final categoryCol = col(['category']);
    final accountCol = col(['account']);
    final toAccountCol = col(
        ['to account', 'to_account', 'toaccount', 'destination', 'transfer to']);

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
    // getAllAccounts orders is_default first, so this is the default account.
    final defaultAccountId = accounts.isEmpty ? 1 : (accounts.first.id ?? 1);

    // Mirrors AccountProvider.currencyOfAccount: a blank account currency
    // means the base currency, so '' and an explicit base code are the same
    // thing and must not read as a mismatch.
    final baseCurrency =
        (await SharedPreferences.getInstance()).getString('currencyCode') ?? '';
    final accountCurrency = <int, String>{
      for (final a in accounts)
        if (a.id != null) a.id!: a.currency,
    };
    String currencyOf(int id) {
      final code = accountCurrency[id] ?? '';
      return code.isEmpty ? baseCurrency : code;
    }

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
        // A blank date marks structural filler, not a transaction — our own
        // xlsx ends the sheet with a TOTAL row, and hand-edited files pick up
        // trailing blank rows. Skip those quietly; a date that is present but
        // unparseable is still bad data worth reporting.
        if (rawDate.isEmpty) continue;
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
        // A transfer is stored on its source account as an expense, with the
        // destination carried in transfer_account_id.
        final isTransferRow = typeVal == 'transfer';
        if (isTransferRow) {
          isExpense = true;
        } else if (typeVal == 'expense') {
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

        final accountId = await _resolveAccount(
            cell(accountCol), accountByName, defaultAccountId);

        if (isTransferRow) {
          final toName = cell(toAccountCol);
          if (toName.isEmpty) {
            throw 'transfer row has no destination account';
          }
          final toAccountId =
              await _resolveAccount(toName, accountByName, defaultAccountId);
          if (toAccountId == accountId) {
            throw 'transfer moves money to the same account';
          }
          // The rule TransactionProvider.addTransfer enforces: one amount
          // booked against two currencies would create or destroy money.
          final from = currencyOf(accountId);
          final to = currencyOf(toAccountId);
          if (from != to) {
            throw 'transfer between $from and $to accounts is not supported';
          }
          toInsert.add(Transaction.createTransfer(
            id: newId(),
            amount: amount,
            fromAccountId: accountId,
            toAccountId: toAccountId,
            date: date,
            title: title,
          ));
          continue;
        }

        // Below the transfer branch on purpose: transfers carry no category,
        // and resolving one here would create a junk category per import.
        final categoryName = cell(categoryCol);
        final categoryId =
            await _resolveCategory(categoryName, isExpense, categoryByKey);

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

  /// Case-insensitive account match; creates the account once (cached) if it
  /// doesn't exist. Falling back to the default account instead silently
  /// merged another account's history into it and wrecked its balance.
  Future<int> _resolveAccount(
    String name,
    Map<String, int> cache,
    int defaultAccountId,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return defaultAccountId;

    final key = trimmed.toLowerCase();
    final hit = cache[key];
    if (hit != null) return hit;

    final newAccountId = await AccountDBHelper().insertAccount(
      Account.createNew(
        name: trimmed,
        icon: 'wallet',
        color: '#607D8B',
        // Credit cards are liabilities; the wrong type flips the sign on every
        // balance calculation for the account.
        type: AccountType.inferLegacy(trimmed, ''),
      ),
    );
    cache[key] = newAccountId;
    return newAccountId;
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
