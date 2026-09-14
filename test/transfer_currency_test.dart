import 'package:flutter_test/flutter_test.dart';
import 'package:coin_manager/providers/transaction_provider.dart';

/// A transfer is stored as one row: the amount is subtracted from the source
/// account and added to the destination. If those accounts held different
/// currencies, that single number would be booked at two different values —
/// $100 leaves, ₹100 arrives — silently destroying money and misstating net
/// worth with nothing in the history to explain it.
///
/// The guard runs before any database access, so these exercise the real
/// provider path without a sqflite binding.
void main() {
  group('cross-currency transfers are refused', () {
    late TransactionProvider provider;

    setUp(() => provider = TransactionProvider());

    Future<void> transfer() => provider.addTransfer(
          fromAccountId: 1,
          toAccountId: 2,
          amount: 100,
          date: DateTime(2026, 3, 1),
        );

    test('throws when the two accounts hold different currencies', () async {
      provider.accountCurrencyResolver = (id) => id == 1 ? 'USD' : 'INR';

      await expectLater(
        transfer(),
        throwsA(isA<TransferCurrencyMismatch>()
            .having((e) => e.fromCurrency, 'fromCurrency', 'USD')
            .having((e) => e.toCurrency, 'toCurrency', 'INR')),
      );
    });

    test('the message names both currencies and suggests a way forward',
        () async {
      provider.accountCurrencyResolver = (id) => id == 1 ? 'GBP' : 'JPY';

      try {
        await transfer();
        fail('expected TransferCurrencyMismatch');
      } on TransferCurrencyMismatch catch (e) {
        expect(e.toString(), contains('GBP'));
        expect(e.toString(), contains('JPY'));
        expect(e.toString(), contains('income'));
      }
    });

    test('accounts with no currency set are treated as one currency, so '
        'existing single-currency users are never blocked', () async {
      // Pre-multi-currency accounts store an empty code; AccountProvider maps
      // those to the base currency, so both sides resolve equal.
      provider.accountCurrencyResolver = (_) => 'USD';

      // Passes the guard, then fails at the DB layer (no binding in a unit
      // test) — which is precisely the point: it was not rejected as a
      // currency mismatch.
      await expectLater(
        transfer(),
        throwsA(isNot(isA<TransferCurrencyMismatch>())),
      );
    });

    test('same currency on both sides is allowed through the guard', () async {
      provider.accountCurrencyResolver = (_) => 'INR';

      await expectLater(
        transfer(),
        throwsA(isNot(isA<TransferCurrencyMismatch>())),
      );
    });

    test('no resolver wired leaves behaviour unchanged', () async {
      // Defensive: the provider must not hard-fail when the hook is absent.
      expect(provider.accountCurrencyResolver, isNull);

      await expectLater(
        transfer(),
        throwsA(isNot(isA<TransferCurrencyMismatch>())),
      );
    });
  });
}
