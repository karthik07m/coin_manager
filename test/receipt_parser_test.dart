import 'package:coin_manager/services/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Receipt text shaped the way ML Kit actually returns it, including the two
/// layouts that made real Giant and Patel Brothers receipts scan as zero.
void main() {
  group('amount — the reported failures', () {
    test('a "TOTAL SAVINGS" line does not become the amount', () {
      // Giant prints savings near the bottom, often 0.00. Scanning upward for
      // anything containing "total" hits this first and reports zero.
      const receipt = '''
GIANT FOOD
BANANAS 1.29
MILK 2% 3.49
BREAD 2.99
SUBTOTAL 7.77
TAX 0.47
TOTAL 8.24
VISA DEBIT 8.24
CHANGE 0.00
YOUR TOTAL SAVINGS 0.00
''';

      expect(ReceiptParser.parse(receipt).amount, 8.24);
    });

    test('label and price split into separate OCR columns', () {
      // The price column is read as its own block, so no line contains both
      // the word TOTAL and a number.
      const receipt = '''
PATEL BROTHERS
TOOR DAL
BASMATI RICE
PANEER
SUBTOTAL
TAX
TOTAL
6.99
18.49
4.29
29.77
1.79
31.56
''';

      expect(ReceiptParser.parse(receipt).amount, 31.56);
    });

    test('amounts with no currency symbol are still found', () {
      const receipt = 'STORE\nITEM 5.00\nTOTAL 12.34\n';
      expect(ReceiptParser.parse(receipt).amount, 12.34);
    });
  });

  group('amount — decoys below the total', () {
    test('change is not the amount', () {
      const receipt = 'SHOP\nTOTAL 45.67\nCASH 50.00\nCHANGE 4.33\n';
      expect(ReceiptParser.parse(receipt).amount, 45.67);
    });

    test('card tender lines are not the amount', () {
      const receipt = 'SHOP\nTOTAL 45.67\nMASTERCARD 45.67\nAUTH 123456\n';
      expect(ReceiptParser.parse(receipt).amount, 45.67);
    });

    test('subtotal loses to total', () {
      const receipt = 'SHOP\nSUBTOTAL 40.00\nTAX 5.67\nTOTAL 45.67\n';
      expect(ReceiptParser.parse(receipt).amount, 45.67);
    });

    test('subtotal is used when no total is printed', () {
      const receipt = 'SHOP\nITEM 10.00\nSUBTOTAL 40.00\n';
      expect(ReceiptParser.parse(receipt).amount, 40.00);
    });

    test('tax is never mistaken for the total', () {
      const receipt = 'SHOP\nITEM 10.00\nTAX 0.60\n';
      expect(ReceiptParser.parse(receipt).amount, 10.00);
    });
  });

  group('amount — number formats', () {
    test('thousands separators are not truncated', () {
      // "1,234.56" must not be read as 234.56.
      const receipt = 'FURNITURE\nTOTAL 1,234.56\n';
      expect(ReceiptParser.parse(receipt).amount, 1234.56);
    });

    test('european format is understood', () {
      const receipt = 'LADEN\nGESAMT\nTOTAL 1.234,56\n';
      expect(ReceiptParser.parse(receipt).amount, 1234.56);
    });

    test('rupee amounts are found', () {
      const receipt = 'KIRANA\nTOTAL ₹1,250.00\n';
      expect(ReceiptParser.parse(receipt).amount, 1250.00);
    });

    test('the rightmost figure on a total line wins', () {
      // Receipts print "TOTAL 3 ITEMS 45.67"; the count is not the amount.
      const receipt = 'SHOP\nTOTAL 3 ITEMS 45.67\n';
      expect(ReceiptParser.parse(receipt).amount, 45.67);
    });

    test('a receipt with no amounts at all yields null, not zero', () {
      expect(ReceiptParser.parse('THANK YOU\nCOME AGAIN').amount, isNull);
    });

    test('falls back to the largest figure when nothing is labelled', () {
      const receipt = 'SHOP\nITEM A 5.00\nITEM B 12.50\nITEM C 3.25\n';
      expect(ReceiptParser.parse(receipt).amount, 12.50);
    });
  });

  group('title', () {
    test('skips a phone number header', () {
      const receipt = '703-555-0142\nGIANT FOOD\nTOTAL 8.24\n';
      expect(ReceiptParser.parse(receipt).title, 'GIANT FOOD');
    });

    test('skips a street address header', () {
      const receipt = '123 Main Street\nPATEL BROTHERS\nTOTAL 31.56\n';
      expect(ReceiptParser.parse(receipt).title, 'PATEL BROTHERS');
    });

    test('keeps the store name when it comes first', () {
      const receipt = 'GIANT FOOD\n123 Main Street\nTOTAL 8.24\n';
      expect(ReceiptParser.parse(receipt).title, 'GIANT FOOD');
    });
  });

  group('date', () {
    test('a named month is parsed', () {
      // The old parser fed "Jan" to int.parse and threw, so these were lost.
      final date = ReceiptParser.parse('SHOP\nJan 15, 2026\nTOTAL 8.24').date;
      expect(date, DateTime(2026, 1, 15));
    });

    test('ISO dates are parsed', () {
      expect(ReceiptParser.parse('SHOP\n2026-08-17\nTOTAL 8.24').date,
          DateTime(2026, 8, 17));
    });

    test('a day above 12 disambiguates day-first order', () {
      expect(ReceiptParser.parse('SHOP\n17/08/2026\nTOTAL 8.24').date,
          DateTime(2026, 8, 17));
    });

    test('two-digit years are expanded', () {
      expect(ReceiptParser.parse('SHOP\n08/17/26\nTOTAL 8.24').date,
          DateTime(2026, 8, 17));
    });

    test('an impossible date is rejected rather than rolled over', () {
      // 13/45/2026 must not silently become some other month.
      expect(ReceiptParser.parse('SHOP\n13/45/2026\nTOTAL 8.24').date, isNull);
    });
  });
}
