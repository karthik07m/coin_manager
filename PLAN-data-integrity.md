# PLAN: Data integrity hardening (IDs, silent failures, orphans)

**Rank: 3 of 5.** Three latent data-loss/corruption classes exist today:
millisecond-timestamp IDs that collide under fast input, DB errors swallowed
into `return -1` with zero logging, and orphaned rows/files when linked records
are deleted. Finance apps live or die on data trust.

## Goal

Collision-proof IDs, visible (logged) DB failures, no orphaned receipts, and an
overpayment guard at the provider layer.

## Exact files to touch

- `pubspec.yaml` — add `uuid: ^4.5.1`
- ID call sites (7 files):
  `lib/providers/debt_provider.dart`, `lib/providers/transaction_provider.dart`,
  `lib/screens/onboarding_screen.dart`, `lib/screens/debt_form_screen.dart`,
  `lib/screens/transaction_form.dart`, `lib/screens/goal_form_screen.dart`,
  `lib/screens/menu_scrn.dart`
- `lib/db/transaction_db_helper.dart`, `lib/db/debt_db_helper.dart`,
  `lib/db/goal_db_helper.dart` — logging in catch blocks
- `lib/providers/transaction_provider.dart` — receipt cleanup on delete
- `lib/providers/debt_provider.dart` — overpayment guard

## Step-by-step

1. Add `uuid: ^4.5.1` to `pubspec.yaml` dependencies; `flutter pub get`.
2. Create a tiny helper `lib/utilities/id_generator.dart`:
   ```dart
   import 'package:uuid/uuid.dart';
   const _uuid = Uuid();
   String newId() => _uuid.v4();
   ```
3. Replace every `DateTime.now().millisecondsSinceEpoch.toString()` ID with
   `newId()` (import the helper). Grep to find all:
   `grep -rn "millisecondsSinceEpoch.toString()" lib`
   **Edge cases:**
   - In `transaction_provider.dart` the recurring-instance generator builds
     `millisecondsSinceEpoch.toString() + originalTransaction.id.substring(0, 5)`.
     Replace the whole expression with `newId()`. The `.substring(0, 5)` exists
     only to dodge collisions — uuid makes it obsolete. **Do not keep the
     substring**: once IDs are uuids, `id.substring(0,5)` on a uuid is harmless,
     but on old millis IDs it's digits — either way it's dead weight.
   - Some sites use `UniqueKey().toString()` (transaction form, settlement
     transactions, receipts). Replace those with `newId()` too for uniformity —
     `UniqueKey` is only unique within one process run.
   - Existing rows keep their old IDs. That is fine — IDs are opaque strings
     everywhere (verify: `recurrenceId` comparisons are equality-only).
4. DB helper logging. In `transaction_db_helper.dart`, `debt_db_helper.dart`,
   `goal_db_helper.dart`: every `catch (e) { return -1; }` (and the `return []`
   / `return null` variants on insert/update/delete/query methods) becomes:
   ```dart
   } catch (e) {
     debugPrint('DB <helper>.<method> failed: $e');
     return -1; // (or [], null — keep the existing fallback)
   }
   ```
   Import `package:flutter/foundation.dart` where missing. **Do not rethrow** —
   the providers already branch on the sentinel values and the UI shows
   failure snackbars; this step is about making failures diagnosable, not about
   changing control flow.
5. Receipt orphan cleanup. In `TransactionProvider.deleteTransaction` (file
   `lib/providers/transaction_provider.dart`), after the transaction row is
   deleted: if `transaction.receiptId != null`, fetch the receipt via
   `ReceiptDBHelper().getReceiptById(...)`, delete the image file
   (`final f = File(receipt.imagePath); if (await f.exists()) await f.delete();`)
   then `ReceiptDBHelper().deleteReceipt(receipt.id)`.
   **Edge cases:**
   - Check the actual method names on `ReceiptDBHelper` first
     (`grep -n "Future" lib/db/receipt_db_helper.dart`) — implement against what
     exists; add a `deleteReceipt(String id)` method there if missing.
   - Wrap file deletion in try/catch with `debugPrint` — a missing file must
     not abort the transaction deletion.
   - `stopRecurringPayment` deletes future instances in bulk via SQL — those
     generated instances never carry receipts (generator doesn't set
     `receiptId`), so no cleanup needed there. Leave it alone.
   - Import `dart:io` in the provider.
6. Overpayment guard in `DebtProvider.recordPayment`
   (`lib/providers/debt_provider.dart`): before inserting, compute
   `final remaining = debt.getRemainingAmount();` and reject when
   `payment.amount > remaining + 0.005`.
   **Edge case — the epsilon is mandatory:** `markAsPaid` records exactly the
   remaining amount, and doubles accumulate error (e.g. remaining
   `33.333333333333336`). A strict `>` on raw doubles will randomly reject
   legitimate final payments. Also note the debt must be fetched BEFORE
   `insertPayment` (currently it is fetched after) — reorder so the guard runs
   before any write; keep the rest of the method's order intact.
7. Compensation for linked settlements. In
   `lib/screens/debt_detail_screen.dart`, the Record Payment submit creates the
   settlement transaction FIRST, then records the payment. If
   `recordPayment(...)` returns false, delete the just-created transaction:
   `await transactionProvider.deleteTransaction(settlementTransactionId)` —
   guard with `if (settlementTransactionId != null && !success)`. Same pattern
   in `_markAsPaid`.
8. `flutter analyze` → clean; `flutter test` → green;
   `flutter build apk --debug --target-platform android-arm64` → builds.

## Acceptance criteria

- [ ] `grep -rn "millisecondsSinceEpoch.toString()" lib` returns nothing
- [ ] `grep -rn "UniqueKey().toString()" lib` returns nothing
- [ ] `grep -c "debugPrint" lib/db/goal_db_helper.dart` ≥ 6 (one per swallowed catch)
- [ ] Manual: delete a transaction that has a receipt → its image file is gone
      from the app documents `receipts/` dir and the receipt row is gone
- [ ] Manual: on a debt with 100 remaining, recording a 150 payment is rejected
      with the existing "cannot exceed remaining balance" path still intact in
      the UI, AND a direct provider call with 150 returns false
- [ ] Manual: Mark as Paid still works (epsilon guard does not block it)
- [ ] Analyzer clean, tests green, debug APK builds
