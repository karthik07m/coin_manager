import 'dart:io';

import 'package:excel/excel.dart';
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

/// Builds a polished, banded, currency-formatted .xlsx workbook — a
/// "Summary" sheet with headline KPIs plus category/account breakdowns,
/// and a "Transactions" sheet styled like a bank/finance-app statement.
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  // Brand palette — matches AppColors so the export feels like Coinly, not
  // a generic spreadsheet.
  static const _colorInk = 'FF0F1115'; // AppColors.background
  static const _colorSurface = 'FF181B21'; // AppColors.surface
  static const _colorEmerald = 'FF2ECC71'; // AppColors.positive / primary
  static const _colorRed = 'FFFF5252'; // AppColors.negative
  static const _colorBlue = 'FF3498DB'; // AppColors.accentBlue
  static const _colorPurple = 'FF9B59B6'; // AppColors.accentPurple
  static const _colorAmber = 'FFFFA726'; // AppColors.warning
  static const _colorGold = 'FFFFD700'; // AppColors.secondary
  static const _colorTextDark = 'FF27272A';
  static const _colorTextGray = 'FF71717A';
  static const _colorBandLight = 'FFF7F8FA';
  static const _colorBorder = 'FFE4E4E7';
  static const _colorWhite = 'FFFFFFFF';

  static const _categoryColors = [
    _colorEmerald,
    _colorBlue,
    _colorAmber,
    _colorPurple,
    _colorRed,
    _colorGold,
  ];

  // Set at the start of each export so every money cell renders in the
  // currency the user picked in Settings.
  String _currencySymbol = '';
  String _currencyCode = '';

  /// Excel number format for money cells, e.g. `"₹"#,##0.00;[RED]("₹"#,##0.00)`.
  String get _currencyFormatCode {
    final prefix = _currencySymbol.isEmpty ? '' : '"$_currencySymbol"';
    return '$prefix#,##0.00;[RED]($prefix#,##0.00)';
  }

  Future<ExportResult> createTransactionsExcelExport({
    String currencySymbol = '',
    String currencyCode = '',
  }) async {
    _currencySymbol = currencySymbol;
    _currencyCode = currencyCode;

    final transactions = await TransactionDBHelper().getTransactions();
    final categories = await DBHelper().getAllCategories();
    final accounts = await AccountDBHelper().getAllAccounts();

    transactions.sort((a, b) => b.date.compareTo(a.date));

    final categoryMap = {
      for (final item in categories)
        if (item['id'] != null) item['id'] as int: Category.fromMap(item),
    };
    final accountMap = {
      for (final account in accounts)
        if (account.id != null) account.id!: account,
    };

    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheetName, 'Summary');

    _writeSummarySheet(
      excel['Summary'],
      transactions: transactions,
      categoryMap: categoryMap,
      accountMap: accountMap,
    );
    _writeTransactionsSheet(
      excel['Transactions'],
      transactions: transactions,
      categoryMap: categoryMap,
      accountMap: accountMap,
    );

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel workbook');
    }

    final exportsDir = await _exportsDirectory();
    final fileName =
        'coinly_transactions_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final file = File(path.join(exportsDir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    return ExportResult(
      path: file.path,
      fileName: fileName,
      rowCount: transactions.length,
    );
  }

  // ---------------------------------------------------------------------
  // Summary sheet
  // ---------------------------------------------------------------------

  void _writeSummarySheet(
    Sheet sheet, {
    required List<Transaction> transactions,
    required Map<int, Category> categoryMap,
    required Map<int, Account> accountMap,
  }) {
    sheet.setColumnWidth(0, 26);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 18);

    double totalIncome = 0;
    double totalExpenses = 0;
    for (final t in transactions) {
      if (t.isTransfer) continue;
      if (t.isExpense) {
        totalExpenses += t.amount;
      } else {
        totalIncome += t.amount;
      }
    }
    final net = totalIncome - totalExpenses;
    final avgTransaction =
        transactions.isEmpty ? 0.0 : (totalIncome + totalExpenses) / transactions.length;
    final savingsRate = totalIncome > 0 ? net / totalIncome : 0.0;

    DateTime? earliest;
    DateTime? latest;
    for (final t in transactions) {
      if (earliest == null || t.date.isBefore(earliest)) earliest = t.date;
      if (latest == null || t.date.isAfter(latest)) latest = t.date;
    }
    final rangeLabel = (earliest != null && latest != null)
        ? '${DateFormat('MMM d, yyyy').format(earliest)} – ${DateFormat('MMM d, yyyy').format(latest)}'
        : 'No transactions yet';

    int row = 0;

    // --- Branded banner -------------------------------------------------
    sheet.merge(_at(0, row), _at(3, row));
    _setCell(sheet, 0, row, TextCellValue('Coinly'),
        style: _bannerTitleStyle());
    sheet.setRowHeight(row, 32);
    row++;

    sheet.merge(_at(0, row), _at(3, row));
    _setCell(
      sheet,
      0,
      row,
      TextCellValue('Financial Report  •  $rangeLabel'),
      style: _bannerSubtitleStyle(),
    );
    row++;

    sheet.merge(_at(0, row), _at(3, row));
    _setCell(
      sheet,
      0,
      row,
      TextCellValue(
        'Generated ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(DateTime.now())}  •  ${transactions.length} transactions',
      ),
      style: _bannerSubtitleStyle(faint: true),
    );
    row += 2;

    // --- Overview KPIs ---------------------------------------------------
    row = _sectionBand(sheet, row, 'OVERVIEW', span: 4);
    row = _kpiRow(sheet, row, 'Total Income', totalIncome, _colorEmerald);
    row = _kpiRow(sheet, row, 'Total Expenses', totalExpenses, _colorRed);
    row = _kpiRow(sheet, row, 'Net Savings', net, net >= 0 ? _colorEmerald : _colorRed);
    row = _kpiRow(sheet, row, 'Savings Rate', savingsRate, _colorBlue,
        isPercent: true);
    row = _kpiRow(sheet, row, 'Avg. Transaction', avgTransaction, _colorTextDark);
    row++;

    // --- Month by month ---------------------------------------------------
    // The block above answers "how was the period"; this answers "which
    // months were bad". Transfers stay excluded, as everywhere else.
    final monthFormat = DateFormat('yyyy-MM');
    final monthlyIncome = <String, double>{};
    final monthlyExpense = <String, double>{};
    for (final t in transactions) {
      if (t.isTransfer) continue;
      final key = monthFormat.format(t.date);
      if (t.isExpense) {
        monthlyExpense[key] = (monthlyExpense[key] ?? 0) + t.amount;
      } else {
        monthlyIncome[key] = (monthlyIncome[key] ?? 0) + t.amount;
      }
    }
    final months = <String>{...monthlyIncome.keys, ...monthlyExpense.keys}
        .toList()
      ..sort();

    if (months.isNotEmpty) {
      row = _sectionBand(sheet, row, 'MONTH BY MONTH', span: 4);
      _setCell(sheet, 0, row, TextCellValue('Month'),
          style: _tableHeaderStyle());
      _setCell(sheet, 1, row, TextCellValue('Income'),
          style: _tableHeaderStyle(align: HorizontalAlign.Right));
      _setCell(sheet, 2, row, TextCellValue('Expenses'),
          style: _tableHeaderStyle(align: HorizontalAlign.Right));
      _setCell(sheet, 3, row, TextCellValue('Net'),
          style: _tableHeaderStyle(align: HorizontalAlign.Right));
      row++;

      var monthIdx = 0;
      for (final month in months) {
        final income = monthlyIncome[month] ?? 0;
        final expense = monthlyExpense[month] ?? 0;
        final net = income - expense;
        final banded = monthIdx.isOdd;
        _setCell(sheet, 0, row, TextCellValue(month),
            style: _bodyStyle(banded: banded));
        _setCell(sheet, 1, row, DoubleCellValue(income),
            style: _currencyStyle(banded: banded));
        _setCell(sheet, 2, row, DoubleCellValue(expense),
            style: _currencyStyle(banded: banded));
        _setCell(sheet, 3, row, DoubleCellValue(net),
            style: _currencyStyle(
                banded: banded, color: net >= 0 ? _colorEmerald : _colorRed));
        row++;
        monthIdx++;
      }
      row++;
    }

    // --- Spending by category --------------------------------------------
    final categoryTotals = <int, double>{};
    for (final t in transactions) {
      if (!t.isExpense || t.isTransfer) continue;
      categoryTotals[t.categoryId] = (categoryTotals[t.categoryId] ?? 0) + t.amount;
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    row = _sectionBand(sheet, row, 'SPENDING BY CATEGORY', span: 4);
    _setCell(sheet, 0, row, TextCellValue('Category'), style: _tableHeaderStyle());
    _setCell(sheet, 1, row, TextCellValue('Amount'),
        style: _tableHeaderStyle(align: HorizontalAlign.Right));
    _setCell(sheet, 2, row, TextCellValue('% of Spend'),
        style: _tableHeaderStyle(align: HorizontalAlign.Right));
    _setCell(sheet, 3, row, TextCellValue('Share'), style: _tableHeaderStyle());
    row++;

    var colorIdx = 0;
    for (final entry in sortedCategories) {
      final name = categoryMap[entry.key]?.name ?? 'Unknown';
      final pct = totalExpenses > 0 ? entry.value / totalExpenses : 0.0;
      final barColor = _categoryColors[colorIdx % _categoryColors.length];
      final banded = colorIdx.isOdd;

      _setCell(sheet, 0, row, TextCellValue(name),
          style: _bodyStyle(banded: banded));
      _setCell(sheet, 1, row, DoubleCellValue(entry.value),
          style: _currencyStyle(banded: banded));
      _setCell(sheet, 2, row, DoubleCellValue(pct),
          style: _percentStyle(banded: banded));
      _setCell(
        sheet,
        3,
        row,
        TextCellValue('█' * (1 + (pct * 18).round())),
        style: _barStyle(barColor, banded: banded),
      );
      row++;
      colorIdx++;
    }
    row++;

    // --- Balances by account ---------------------------------------------
    row = _sectionBand(sheet, row, 'ACCOUNT BALANCES', span: 4);
    _setCell(sheet, 0, row, TextCellValue('Account'), style: _tableHeaderStyle());
    sheet.merge(_at(1, row), _at(2, row));
    _setCell(sheet, 1, row, TextCellValue('Type'), style: _tableHeaderStyle());
    _setCell(sheet, 3, row, TextCellValue('Balance'),
        style: _tableHeaderStyle(align: HorizontalAlign.Right));
    row++;

    final sortedAccounts = accountMap.values.toList()
      ..sort((a, b) => b.currentBalance.compareTo(a.currentBalance));
    var accIdx = 0;
    for (final account in sortedAccounts) {
      final banded = accIdx.isOdd;
      _setCell(sheet, 0, row, TextCellValue(account.name),
          style: _bodyStyle(banded: banded));
      sheet.merge(_at(1, row), _at(2, row));
      _setCell(sheet, 1, row, TextCellValue(account.type.label),
          style: _bodyStyle(banded: banded));
      _setCell(sheet, 3, row, DoubleCellValue(account.currentBalance),
          style: _currencyStyle(
              banded: banded,
              color: account.currentBalance < 0 ? _colorRed : _colorTextDark));
      row++;
      accIdx++;
    }
  }

  // ---------------------------------------------------------------------
  // Transactions sheet
  // ---------------------------------------------------------------------

  void _writeTransactionsSheet(
    Sheet sheet, {
    required List<Transaction> transactions,
    required Map<int, Category> categoryMap,
    required Map<int, Account> accountMap,
  }) {
    final headers = [
      'Date',
      'Month',
      'Time',
      'Type',
      'Title',
      'Category',
      'Account',
      'To Account',
      _currencyCode.isEmpty ? 'Amount' : 'Amount ($_currencyCode)',
      'Recurring',
      'Receipt',
    ];
    // Row ids and created/modified stamps are database bookkeeping, not
    // statement content — they made the sheet unreadable and nothing reads
    // them back (import matches on date + amount + title).
    const widths = [
      13.0, 10.0, 9.0, 10.0, 34.0, 18.0, 18.0, 18.0, 16.0, 11.0, 10.0
    ];
    // Derived, not hand-numbered: the totals row and header alignment used to
    // carry literal indices that had to be re-counted every time a column moved.
    final amountCol = headers.indexWhere((h) => h.startsWith('Amount'));
    final titleCol = headers.indexOf('Title');
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }

    for (var i = 0; i < headers.length; i++) {
      _setCell(
        sheet,
        i,
        0,
        TextCellValue(headers[i]),
        style: _txnHeaderStyle(
          align: i == amountCol ? HorizontalAlign.Right : HorizontalAlign.Left,
        ),
      );
    }
    sheet.setRowHeight(0, 22);

    final timeFormat = DateFormat('HH:mm');
    // Sortable and pivot-friendly, which is the whole point of the column.
    final monthFormat = DateFormat('yyyy-MM');

    double totalIncome = 0;
    double totalExpenses = 0;

    for (var i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      final rowIndex = i + 1;
      final banded = i.isOdd;
      final category = categoryMap[t.categoryId];
      final account = accountMap[t.accountId];
      final isIncome = !t.isExpense;
      final signedAmount = t.isExpense ? -t.amount : t.amount;

      if (!t.isTransfer) {
        if (isIncome) {
          totalIncome += t.amount;
        } else {
          totalExpenses += t.amount;
        }
      }

      final typeLabel = t.isTransfer ? 'Transfer' : (isIncome ? 'Income' : 'Expense');
      final typeColor = t.isTransfer
          ? _colorTextGray
          : (isIncome ? _colorEmerald : _colorRed);

      // Cursor rather than literals, so the column order lives in `headers`
      // alone and adding one here can't silently shift the rest.
      var c = 0;
      _setCell(sheet, c++, rowIndex,
          DateCellValue(year: t.date.year, month: t.date.month, day: t.date.day),
          style: _dateStyle(banded: banded));
      _setCell(sheet, c++, rowIndex, TextCellValue(monthFormat.format(t.date)),
          style: _bodyStyle(banded: banded, align: HorizontalAlign.Center));
      _setCell(sheet, c++, rowIndex, TextCellValue(timeFormat.format(t.date)),
          style: _bodyStyle(banded: banded, align: HorizontalAlign.Center));
      _setCell(sheet, c++, rowIndex, TextCellValue(typeLabel),
          style: _badgeStyle(typeColor, banded: banded));
      _setCell(sheet, c++, rowIndex, TextCellValue(t.title),
          style: _bodyStyle(banded: banded));
      // A transfer has no category; writing the "Unknown" placeholder made
      // re-import create a junk category by that name.
      _setCell(
          sheet,
          c++,
          rowIndex,
          TextCellValue(t.isTransfer ? '' : (category?.name ?? 'Unknown')),
          style: _bodyStyle(banded: banded));
      _setCell(sheet, c++, rowIndex, TextCellValue(account?.name ?? 'Unknown'),
          style: _bodyStyle(banded: banded));
      // Destination account — the only field that lets a transfer survive a
      // round trip. Blank for everything else.
      _setCell(
          sheet,
          c++,
          rowIndex,
          TextCellValue(t.isTransfer
              ? (accountMap[t.transferAccountId]?.name ?? 'Unknown')
              : ''),
          style: _bodyStyle(banded: banded));
      _setCell(sheet, c++, rowIndex, DoubleCellValue(signedAmount),
          style: _currencyStyle(
              banded: banded, color: t.isTransfer ? _colorTextDark : typeColor));
      _setCell(sheet, c++, rowIndex, TextCellValue(t.isRecurring ? 'Yes' : 'No'),
          style: _bodyStyle(banded: banded, align: HorizontalAlign.Center));
      _setCell(
        sheet,
        c++,
        rowIndex,
        TextCellValue(
            t.receiptId != null && t.receiptId!.trim().isNotEmpty ? 'Yes' : 'No'),
        style: _bodyStyle(banded: banded, align: HorizontalAlign.Center),
      );
    }

    // --- Totals row -------------------------------------------------------
    final totalsRow = transactions.length + 1;
    for (var i = 0; i < headers.length; i++) {
      _setCell(sheet, i, totalsRow, TextCellValue(''),
          style: _totalsLabelStyle());
    }
    _setCell(sheet, titleCol, totalsRow, TextCellValue('TOTAL'),
        style: _totalsLabelStyle());
    _setCell(sheet, amountCol, totalsRow,
        DoubleCellValue(totalIncome - totalExpenses),
        style: _totalsAmountStyle(
            color:
                (totalIncome - totalExpenses) >= 0 ? _colorEmerald : _colorRed));
  }

  // ---------------------------------------------------------------------
  // Style builders
  // ---------------------------------------------------------------------

  CellStyle _bannerTitleStyle() => CellStyle(
        bold: true,
        fontSize: 22,
        fontColorHex: ExcelColor.fromHexString(_colorWhite),
        backgroundColorHex: ExcelColor.fromHexString(_colorInk),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _bannerSubtitleStyle({bool faint = false}) => CellStyle(
        italic: faint,
        fontSize: faint ? 10 : 12,
        fontColorHex: ExcelColor.fromHexString(faint ? 'FFA1A1AA' : _colorEmerald),
        backgroundColorHex: ExcelColor.fromHexString(_colorInk),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _sectionBandStyle() => CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString(_colorWhite),
        backgroundColorHex: ExcelColor.fromHexString(_colorSurface),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _tableHeaderStyle({HorizontalAlign align = HorizontalAlign.Left}) =>
      CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString(_colorTextDark),
        backgroundColorHex: ExcelColor.fromHexString(_colorBandLight),
        horizontalAlign: align,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(
          borderStyle: BorderStyle.Medium,
          borderColorHex: ExcelColor.fromHexString(_colorTextDark),
        ),
      );

  CellStyle _txnHeaderStyle({HorizontalAlign align = HorizontalAlign.Left}) =>
      CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString(_colorWhite),
        backgroundColorHex: ExcelColor.fromHexString(_colorInk),
        horizontalAlign: align,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _bodyStyle({
    bool banded = false,
    bool faint = false,
    HorizontalAlign align = HorizontalAlign.Left,
  }) =>
      CellStyle(
        fontSize: 10,
        fontColorHex:
            ExcelColor.fromHexString(faint ? _colorTextGray : _colorTextDark),
        backgroundColorHex:
            ExcelColor.fromHexString(banded ? _colorBandLight : _colorWhite),
        horizontalAlign: align,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(
          borderStyle: BorderStyle.Hair,
          borderColorHex: ExcelColor.fromHexString(_colorBorder),
        ),
      );

  CellStyle _dateStyle({bool banded = false}) => CellStyle(
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString(_colorTextDark),
        backgroundColorHex:
            ExcelColor.fromHexString(banded ? _colorBandLight : _colorWhite),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        numberFormat: NumFormat.custom(formatCode: 'mmm d, yyyy'),
        bottomBorder: Border(
          borderStyle: BorderStyle.Hair,
          borderColorHex: ExcelColor.fromHexString(_colorBorder),
        ),
      );

  CellStyle _badgeStyle(String color, {bool banded = false}) => CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString(color),
        backgroundColorHex:
            ExcelColor.fromHexString(banded ? _colorBandLight : _colorWhite),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(
          borderStyle: BorderStyle.Hair,
          borderColorHex: ExcelColor.fromHexString(_colorBorder),
        ),
      );

  CellStyle _currencyStyle({bool banded = false, String? color}) => CellStyle(
        bold: color != null,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString(color ?? _colorTextDark),
        backgroundColorHex:
            ExcelColor.fromHexString(banded ? _colorBandLight : _colorWhite),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        numberFormat: NumFormat.custom(formatCode: _currencyFormatCode),
        bottomBorder: Border(
          borderStyle: BorderStyle.Hair,
          borderColorHex: ExcelColor.fromHexString(_colorBorder),
        ),
      );

  CellStyle _percentStyle({bool banded = false}) => CellStyle(
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString(_colorTextDark),
        backgroundColorHex:
            ExcelColor.fromHexString(banded ? _colorBandLight : _colorWhite),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        numberFormat: NumFormat.custom(formatCode: '0.0%'),
      );

  CellStyle _barStyle(String color, {bool banded = false}) => CellStyle(
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString(color),
        backgroundColorHex:
            ExcelColor.fromHexString(banded ? _colorBandLight : _colorWhite),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

  CellStyle _totalsLabelStyle() => CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString(_colorTextDark),
        backgroundColorHex: ExcelColor.fromHexString(_colorBandLight),
        topBorder: Border(
          borderStyle: BorderStyle.Medium,
          borderColorHex: ExcelColor.fromHexString(_colorTextDark),
        ),
      );

  CellStyle _totalsAmountStyle({required String color}) => CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString(color),
        backgroundColorHex: ExcelColor.fromHexString(_colorBandLight),
        horizontalAlign: HorizontalAlign.Right,
        numberFormat: NumFormat.custom(formatCode: _currencyFormatCode),
        topBorder: Border(
          borderStyle: BorderStyle.Medium,
          borderColorHex: ExcelColor.fromHexString(_colorTextDark),
        ),
      );

  // ---------------------------------------------------------------------
  // Small layout helpers
  // ---------------------------------------------------------------------

  CellIndex _at(int col, int row) =>
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);

  void _setCell(Sheet sheet, int col, int row, CellValue value,
      {CellStyle? style}) {
    sheet.updateCell(_at(col, row), value, cellStyle: style);
  }

  /// Writes a full-width section banner and returns the next free row.
  int _sectionBand(Sheet sheet, int row, String title, {required int span}) {
    sheet.merge(_at(0, row), _at(span - 1, row));
    _setCell(sheet, 0, row, TextCellValue(title), style: _sectionBandStyle());
    sheet.setRowHeight(row, 20);
    return row + 1;
  }

  /// Writes a label/value KPI row and returns the next free row.
  int _kpiRow(Sheet sheet, int row, String label, double value, String color,
      {bool isPercent = false}) {
    _setCell(sheet, 0, row, TextCellValue(label),
        style: CellStyle(
          fontSize: 10,
          fontColorHex: ExcelColor.fromHexString(_colorTextDark),
          verticalAlign: VerticalAlign.Center,
        ));
    sheet.merge(_at(1, row), _at(3, row));
    _setCell(
      sheet,
      1,
      row,
      DoubleCellValue(value),
      style: CellStyle(
        bold: true,
        fontSize: 12,
        fontColorHex: ExcelColor.fromHexString(color),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        numberFormat: NumFormat.custom(
          formatCode: isPercent ? '0.0%' : _currencyFormatCode,
        ),
      ),
    );
    return row + 1;
  }

  // ---------------------------------------------------------------------
  // Legacy CSV export (kept for lightweight/plain-text sharing)
  // ---------------------------------------------------------------------

  Future<ExportResult> createTransactionsCsvExport({
    String currencyCode = '',
  }) async {
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
        'Month',
        'Time',
        'Type',
        'Title',
        'Category',
        'Account',
        'To Account',
        currencyCode.isEmpty ? 'Amount' : 'Amount ($currencyCode)',
        'Recurring',
        'Receipt Attached',
      ],
      ...transactions.map(
        (transaction) => _transactionRow(
          transaction,
          categoryMap[transaction.categoryId],
          accountMap[transaction.accountId],
          accountMap[transaction.transferAccountId],
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
    Account? toAccount,
  ) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');

    return [
      dateFormat.format(transaction.date),
      DateFormat('yyyy-MM').format(transaction.date),
      timeFormat.format(transaction.date),
      // Was always Expense/Income, so every transfer left here mislabelled and
      // came back as a plain expense on re-import.
      transaction.isTransfer
          ? 'Transfer'
          : (transaction.isExpense ? 'Expense' : 'Income'),
      transaction.title,
      transaction.isTransfer ? '' : (category?.name ?? 'Unknown'),
      account?.name ?? 'Unknown',
      transaction.isTransfer ? (toAccount?.name ?? 'Unknown') : '',
      transaction.amount.toStringAsFixed(2),
      transaction.isRecurring ? 'Yes' : 'No',
      transaction.receiptId == null || transaction.receiptId!.trim().isEmpty
          ? 'No'
          : 'Yes',
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
