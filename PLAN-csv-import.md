# PLAN: CSV transaction import

**Rank: 5 of 5.** The app exports CSV (`lib/services/export_service.dart`) but
cannot import, so there is no migration path from other apps or from its own
exports after a device wipe. This is the classic adoption blocker. Ranked last
only because the other four protect existing users first.

## Goal

Settings → "Import Transactions CSV": pick a file, parse it (round-trips our
own export format), resolve categories/accounts by name (creating missing
categories), skip duplicates, insert in one batch, and show an
imported/skipped/failed summary.

## Exact files to touch

- `pubspec.yaml` — add `csv: ^6.0.0` (do NOT hand-roll a CSV parser; quoted
  fields containing commas and newlines will silently corrupt rows)
- NEW `lib/services/import_service.dart`
- `lib/screens/setting.dart` — tile under the existing 'Export Transactions CSV'
- `lib/db/transaction_db_helper.dart` — batch insert method
- `lib/db/category_db_helper.dart` — verify/add an insert-category method

## Step-by-step

0. **Read `lib/services/export_service.dart` first** and copy the exact header
   row and column order from `createTransactionsCsvExport` into the importer as
   the canonical format. Build the column-index map from the actual header
   names found in row 0 (case-insensitive, trimmed) — never by position alone,
   so files with reordered columns still import.
1. Add the `csv` package; `flutter pub get`.
2. `ImportService.importTransactionsCsv(String filePath)` returning
   `ImportResult { int imported; int skippedDuplicates; int failed; List<String> errors; }`:
   - Read file → `const CsvToListConverter(shouldParseNumbers: false).convert(raw)`.
     **Edge case:** pass `eol: '\n'` fallback handling — exports from Excel use
     `\r\n`; the csv package handles both only if you normalize first:
     `raw = raw.replaceAll('\r\n', '\n')`.
   - Header row: locate required columns (date, title/note, amount, type or
     is_expense, category, account). Missing any required column → fail fast
     with a clear message listing what was found.
   - Per data row (wrap each row in try/catch; a bad row increments `failed`
     and appends `'Row N: <reason>'`, never aborts the whole import):
     - **Date parsing, in this order:** `DateTime.tryParse` (ISO),
       `DateFormat('MMM dd, yyyy')`, `DateFormat('dd/MM/yyyy')`,
       `DateFormat('MM/dd/yyyy')`. First success wins. All in try/catch —
       `DateFormat.parse` THROWS, it does not return null.
     - **Amount:** strip currency symbols and commas
       (`row.replaceAll(RegExp(r'[^\d.\-]'), '')`), then `double.tryParse`.
       Reject rows with amount ≤ 0 after `abs()` — but preserve sign semantics:
       if there is no explicit type column, a negative amount means expense.
     - **isExpense:** from the type column (`'expense'/'income'`, case-insensitive)
       falling back to the sign rule above.
     - **Category resolution:** case-insensitive name match against
       `DBHelper().getAllCategories()` where `isExpense` matches. No match →
       create it once (icon `'assets/categories/other.png'`) and cache the new
       id in a local map so 500 rows with the same new category create ONE row.
       **Check the actual insert method name on the category helper first**
       (`grep -n "Future" lib/db/category_db_helper.dart`); add one if missing.
     - **Account resolution:** case-insensitive match on
       `AccountDBHelper` accounts; no match → account id 1 (do NOT auto-create
       accounts; they carry balances).
     - **Duplicate detection:** before inserting, build a Set of existing keys
       `'$isoDate|$amount|$titleLowercased'` from ONE upfront
       `getTransactions()` call (do not query per row). Matching key →
       `skippedDuplicates++`.
     - id: use the uuid helper if PLAN-data-integrity landed, else
       `UniqueKey().toString()`. `isRecurring: false` always — imported history
       must never spawn future recurring instances.
3. Batch insert: add to `TransactionDBHelper`:
   ```dart
   Future<int> insertTransactionsBatch(List<trans_model.Transaction> txns) async {
     final db = await database;
     final batch = db.batch();
     for (final t in txns) { batch.insert(tableName, t.toMap()); }
     await batch.commit(noResult: true);
     return txns.length;
   }
   ```
4. Settings UI (`lib/screens/setting.dart`): tile 'Import Transactions CSV'
   below the export tile. Use `FilePicker.platform.pickFiles(type: FileType.custom,
   allowedExtensions: ['csv'])` — `file_picker` is already a dependency (used by
   backup restore; copy its usage pattern from
   `lib/screens/backup_management_screen.dart`). Show a progress dialog while
   importing, then an AlertDialog summary: "Imported 214 · Skipped 3 duplicates ·
   2 failed" with the first 5 error strings listed.
   **Edge case:** after import you MUST refresh app state or the UI shows
   nothing: call `TransactionProvider.loadTransactionsFromDB(startDate:
   firstOfCurrentMonth, endDate: endOfCurrentMonth)` and
   `loadUpcomingTransactions()` (mirror the exact call in
   `home_scrn.dart:_fetchData`).
5. `flutter analyze`; `flutter test`; build debug APK.
6. Round-trip test by hand: export CSV from Settings, delete one transaction in
   the app, import the exported file → exactly 1 imported, rest skipped as
   duplicates.

## Edge cases recap

- Quoted commas/newlines/`""` escapes → csv package, never `split(',')`.
- `\r\n` line endings from Excel.
- `DateFormat.parse` throws; wrap everything per-row.
- Duplicate check via upfront Set, not per-row queries (O(n) not O(n²)).
- Cache created categories to avoid duplicate category rows within one import.
- Never import `isRecurring: true` — it would generate phantom future bills.
- Amounts arrive with currency symbols (`₹1,234.56`) in our own export — strip
  before parsing; keep the sign rule for third-party files.
- Reload providers after import or the imported data is invisible until restart.

## Acceptance criteria

- [ ] Settings shows Import tile; picking a non-CSV or malformed file shows an
      error dialog, not a crash
- [ ] Round-trip (export → delete 1 → import) yields imported=1, duplicates=rest
- [ ] A CSV with an unknown category creates that category exactly once
- [ ] A CSV row with garbage date increments `failed` and appears in the error
      list; other rows still import
- [ ] Home totals/budget card update immediately after import (no restart)
- [ ] Analyzer clean, tests green, debug APK builds
