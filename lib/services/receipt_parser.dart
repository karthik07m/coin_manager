import 'dart:math' as math;

/// What a receipt scan managed to read out of the OCR text.
class ReceiptFields {
  final double? amount;
  final String? title;
  final DateTime? date;

  const ReceiptFields({this.amount, this.title, this.date});
}

/// Turns OCR text from a receipt into an amount, a store name and a date.
///
/// Kept free of plugins and file I/O so it can be tested against real receipt
/// text — which is the only way to get this right, because the failure modes
/// are all about the shapes real receipts take:
///
///  * "TOTAL" and its number often land on different lines, because OCR reads
///    the label column and the price column as separate blocks.
///  * The bottom of a receipt is full of decoys — CHANGE, CASH, card tender,
///    tax, and "TOTAL SAVINGS", which contains the word "total" and is
///    frequently 0.00. Taking the bottom-most match returns that zero.
///  * US grocery receipts print amounts with no currency symbol at all.
class ReceiptParser {
  const ReceiptParser._();

  /// Amount with optional currency symbol, optional thousands separators.
  /// Requires the cents pair, which is what distinguishes a price from a
  /// quantity, a phone number or a store number.
  static final RegExp _amount = RegExp(
    r'(?<![\d.,])'
    r'[\$€£₹]?\s*'
    r'(\d{1,3}(?:,\d{3})+\.\d{2}|\d+\.\d{2}|\d{1,3}(?:\.\d{3})+,\d{2}|\d+,\d{2})'
    r'(?![\d.,]*\d)',
  );

  /// Lines that name the figure we want.
  static final RegExp _totalLabel = RegExp(
    r'\b(grand\s*total|total\s*due|total\s*sale|amount\s*due|balance\s*due|'
    r'amount\s*paid|to\s*pay|total)\b',
    caseSensitive: false,
  );

  static final RegExp _subtotalLabel = RegExp(
    r'\b(sub\s*-?\s*total|sub\s*tot)\b',
    caseSensitive: false,
  );

  /// Lines whose number is never the amount charged, even when they contain
  /// the word "total" — "YOUR TOTAL SAVINGS" being the one that turns a
  /// receipt into a zero.
  static final RegExp _decoyLabel = RegExp(
    r'\b(saving|saved|you\s*save|change|cash\s*back|cashback|tender|'
    r'card|visa|mastercard|amex|discover|debit|credit|account|auth|'
    r'points|reward|coupon|discount|tax|vat|gst|hst|pst|'
    r'balance\s*forward|previous|tip|gratuity|qty|quantity|item\s*count)\b',
    caseSensitive: false,
  );

  static ReceiptFields parse(String rawText) {
    final rawLines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final lines = _mergeSplitColumns(rawLines);

    return ReceiptFields(
      amount: _findAmount(lines),
      title: _findTitle(lines),
      date: _findDate(lines),
    );
  }

  // ---------------------------------------------------------------- columns

  /// Rejoins a receipt whose label column and price column were read as two
  /// separate blocks, which is how OCR usually returns them when the gap
  /// between name and price is wide.
  ///
  /// The two runs are paired from the bottom up, because the header lines
  /// (store name, address) sit in the label column with no price beside them,
  /// so the columns line up at the end rather than the start.
  static List<String> _mergeSplitColumns(List<String> lines) {
    final merged = <String>[];
    var i = 0;

    while (i < lines.length) {
      final labelStart = i;
      while (i < lines.length && _amountsIn(lines[i]).isEmpty) {
        i++;
      }
      final labels = lines.sublist(labelStart, i);

      final amountStart = i;
      while (i < lines.length && _isAmountOnly(lines[i])) {
        i++;
      }
      final amounts = lines.sublist(amountStart, i);

      // Two lone lines aren't a column; require a run on both sides before
      // assuming this layout, so ordinary receipts pass through untouched.
      if (labels.length >= 2 && amounts.length >= 2) {
        final pairCount = math.min(labels.length, amounts.length);
        merged.addAll(labels.sublist(0, labels.length - pairCount));
        merged.addAll(amounts.sublist(0, amounts.length - pairCount));
        for (var k = 0; k < pairCount; k++) {
          final label = labels[labels.length - pairCount + k];
          final amount = amounts[amounts.length - pairCount + k];
          merged.add('$label $amount');
        }
      } else {
        merged.addAll(labels);
        merged.addAll(amounts);
      }

      // A line holding both a label and a figure belongs to neither run;
      // emit it as-is and keep moving so this can never spin.
      if (labels.isEmpty && amounts.isEmpty) {
        merged.add(lines[i]);
        i++;
      }
    }

    return merged;
  }

  // ----------------------------------------------------------------- amount

  static double? _findAmount(List<String> lines) {
    final amountsByLine = <int, List<double>>{};
    for (var i = 0; i < lines.length; i++) {
      final values = _amountsIn(lines[i]);
      if (values.isNotEmpty) amountsByLine[i] = values;
    }
    if (amountsByLine.isEmpty) return null;

    // 1. A labelled total, preferring the last one on the receipt: stores
    //    print the real total after the itemised list.
    final labelled = _labelledAmount(lines, amountsByLine, _totalLabel);
    if (labelled != null) return labelled;

    // 2. Subtotal is a worse answer than the total but a much better one
    //    than nothing, and on receipts with no tax the two are equal.
    final subtotal = _labelledAmount(lines, amountsByLine, _subtotalLabel);
    if (subtotal != null) return subtotal;

    // 3. Nothing was labelled. The charged amount is almost always the
    //    largest figure on a receipt, since it is the sum of the rest.
    final all = amountsByLine.entries
        .where((entry) => !_decoyLabel.hasMatch(lines[entry.key]))
        .expand((entry) => entry.value)
        .where((value) => value > 0)
        .toList();
    if (all.isEmpty) return null;
    return all.reduce(math.max);
  }

  /// Finds the amount belonging to a labelled line, looking on the line
  /// itself and then down the column when OCR split label from price.
  static double? _labelledAmount(
    List<String> lines,
    Map<int, List<double>> amountsByLine,
    RegExp label,
  ) {
    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (!label.hasMatch(line)) continue;
      if (_decoyLabel.hasMatch(line)) continue;
      // "TOTAL" alone is what we want; "SUBTOTAL" must not satisfy the
      // total pattern via its trailing "total".
      if (label == _totalLabel && _subtotalLabel.hasMatch(line)) continue;

      final onLine = amountsByLine[i]?.where((v) => v > 0).toList();
      if (onLine != null && onLine.isNotEmpty) {
        // Rightmost number on the line is the price column.
        return onLine.last;
      }

      // Label and price were read as separate blocks. Take the next line
      // that is nothing but an amount, so an item name can't be mistaken
      // for the total.
      for (var j = i + 1; j < lines.length && j <= i + 3; j++) {
        if (_decoyLabel.hasMatch(lines[j])) continue;
        final values = amountsByLine[j];
        if (values == null || values.isEmpty) continue;
        if (!_isAmountOnly(lines[j])) continue;
        final positive = values.where((v) => v > 0).toList();
        if (positive.isNotEmpty) return positive.last;
      }
    }
    return null;
  }

  static List<double> _amountsIn(String line) {
    return _amount
        .allMatches(line)
        .map((m) => _toDouble(m.group(1)!))
        .whereType<double>()
        .toList();
  }

  /// True when the line carries a figure and nothing that reads like a label,
  /// e.g. "8.24" or "$8.24".
  static bool _isAmountOnly(String line) {
    final stripped = line.replaceAll(_amount, '').replaceAll(RegExp(r'[\s\-*:]'), '');
    return stripped.isEmpty;
  }

  /// Handles both 1,234.56 and 1.234,56 conventions.
  static double? _toDouble(String raw) {
    var text = raw.trim();
    final lastComma = text.lastIndexOf(',');
    final lastDot = text.lastIndexOf('.');

    if (lastComma > lastDot) {
      // Comma is the decimal separator; dots group thousands.
      text = text.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // Dot is the decimal separator; commas group thousands.
      text = text.replaceAll(',', '');
    }
    return double.tryParse(text);
  }

  // ------------------------------------------------------------------ title

  /// The store name, skipping the header noise receipts open with: a phone
  /// number, an address, a store number, or the word "receipt".
  static final RegExp _headerNoise = RegExp(
    r'(\d{3}[-.\s]?\d{3}[-.\s]?\d{4})|'
    r'(\b\d+\s+[A-Za-z].*\b(st|street|ave|avenue|rd|road|blvd|dr|drive|ln|lane|way|hwy|pkwy|suite|ste)\b)|'
    r'^\s*(store|receipt|invoice|tel|phone|fax|order|www\.|http)',
    caseSensitive: false,
  );

  static String? _findTitle(List<String> lines) {
    for (final line in lines.take(6)) {
      final cleaned = line.trim();
      if (cleaned.length < 3) continue;
      if (_headerNoise.hasMatch(cleaned)) continue;
      // A line that is mostly digits is a store or terminal number.
      final letters = cleaned.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
      if (letters < 3) continue;
      return cleaned;
    }
    return lines.isNotEmpty ? lines.first : null;
  }

  // ------------------------------------------------------------------- date

  static final List<String> _months = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];

  static final RegExp _isoDate = RegExp(r'\b(\d{4})[/-](\d{1,2})[/-](\d{1,2})\b');
  static final RegExp _numericDate =
      RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b');
  static final RegExp _namedMonthDate = RegExp(
    r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+'
    r'(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{2,4})\b',
    caseSensitive: false,
  );

  static DateTime? _findDate(List<String> lines) {
    for (final line in lines) {
      final iso = _isoDate.firstMatch(line);
      if (iso != null) {
        final parsed = _safeDate(int.parse(iso.group(1)!),
            int.parse(iso.group(2)!), int.parse(iso.group(3)!));
        if (parsed != null) return parsed;
      }

      final named = _namedMonthDate.firstMatch(line);
      if (named != null) {
        // The old parser fed a month *name* to int.parse here and threw, so
        // "Jan 15, 2026" never produced a date.
        final month =
            _months.indexOf(named.group(1)!.toLowerCase().substring(0, 3)) + 1;
        final parsed = _safeDate(_fullYear(int.parse(named.group(3)!)), month,
            int.parse(named.group(2)!));
        if (parsed != null) return parsed;
      }

      final numeric = _numericDate.firstMatch(line);
      if (numeric != null) {
        final first = int.parse(numeric.group(1)!);
        final second = int.parse(numeric.group(2)!);
        final year = _fullYear(int.parse(numeric.group(3)!));
        // Only the day can exceed 12, so it disambiguates the order.
        final parsed = first > 12
            ? _safeDate(year, second, first)
            : _safeDate(year, first, second);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static int _fullYear(int year) => year >= 100 ? year : 2000 + year;

  /// Rejects impossible dates rather than letting DateTime roll them over
  /// into a wrong month.
  static DateTime? _safeDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.month != month || date.day != day) return null;
    return date;
  }
}
