# PLAN: Unit tests for the money math

**Rank: 2 of 5.** This session found and fixed at least four real math bugs by
hand (current-month misclassified as future, elapsed/remaining day-count
mismatch, naive projection multiplying one-time rent across 31 days, a
self-comparing status check that never persisted). Nothing prevents them from
regressing. All the interesting logic is now pure Dart — cheap to test, no
device needed.

## Goal

A `flutter test` suite covering `BudgetProjection`, money formatting, and the
Debt/Goal model math, so every future refactor of these files is caught by CI
(`tool/verify.sh` from PLAN-verify-and-commit runs `flutter test`).

## Exact files to touch

- `lib/utilities/budget_projection.dart` — one small refactor for testability (step 1)
- `test/budget_projection_test.dart` — new
- `test/money_format_test.dart` — new
- `test/debt_model_test.dart` — new
- `test/goal_model_test.dart` — new
- `test/widget_test.dart` — inspect; delete if it is the stock counter template

## Step-by-step

1. **Make `BudgetProjection.compute` testable.** It calls `DateTime.now()`
   internally, which makes results time-dependent. Add an optional parameter:
   ```dart
   static BudgetProjection compute({
     required List<Transaction> monthExpensesToDate,
     required List<Transaction> upcomingRecurring,
     required DateTime selectedMonth,
     required double totalBudget,
     DateTime? now,   // NEW — tests inject a fixed clock
   }) {
     final DateTime clock = now ?? DateTime.now();
   ```
   Replace every internal use of `DateTime.now()` (there is exactly one, at the
   top) with `clock`. Do NOT change any call site — the default preserves
   behavior. Run `flutter analyze` after.
2. **`test/budget_projection_test.dart`.** Build `Transaction` objects with
   `Transaction.createNew(id:, title:, amount:, categoryId: 1, accountId: 1,
   date:, isExpense: true, isRecurring: ...)`. Fixed clock:
   `final now = DateTime(2026, 7, 6);` (July 2026 has 31 days; day 6 → elapsed 5,
   remaining 26). Cases — each is a documented invariant, not a guess:
   - **Elapsed/remaining convention:** with one non-recurring 100.0 expense on
     July 2 and budget 3100, projection = `100 + 0 + (100/5)*26 = 620.0`.
     (Elapsed is `now.day - 1`; today counts as remaining. A weaker model will
     be tempted to use `now.day` = 6 — that is the bug this codebase already
     fixed once.)
   - **Recurring excluded from run-rate:** rent 2000 (`isRecurring: true`,
     July 1) + 100 variable (July 2), budget 4800 → projected
     `2100 + 0 + (100/5)*26 = 2620.0`. NOT `2100/5*31`.
   - **Large one-time excluded:** rent 2000 logged NON-recurring, budget 4800.
     Threshold is `totalBudget * 0.20 = 960`, and the check is `>=`, so 2000 is
     excluded from run-rate but still in "spent": same 2620.0 as above.
   - **Zero budget disables the large-one-time filter:** budget 0 → threshold is
     `double.infinity`, so a 2000 one-time DOES enter the run-rate:
     projected `2100 + (2100/5)*26`.
   - **Upcoming recurring added once:** pass `upcomingRecurring` containing an
     expense dated July 15 amount 327 and another dated August 3 amount 500 —
     only the July one is added (August is after end-of-month). Also include an
     income (`isExpense: false`) dated July 20 — must be ignored.
   - **Past month:** `selectedMonth = DateTime(2026, 6, 15)` with clock in July →
     projected == sum of monthExpensesToDate exactly; variableDailyAverage == 0.
   - **Future month:** `selectedMonth = DateTime(2026, 8, 1)` → projected == 0.
   - **Day 1 edge:** clock `DateTime(2026, 7, 1)` → `daysElapsed` clamps to 1
     (never divide by zero).
3. **`test/money_format_test.dart`** for `UtilityFunction` in
   `lib/utilities/functions.dart`:
   - `formatIndianNumber(1234567.89)` → `'12,34,567.89'`; with
     `showDecimals: false` → `'12,34,567'`; negative → leading `-`.
   - `formatIndianCompact(12500000)` → `'₹1.3Cr'`; `formatIndianCompact(250000)`
     → `'₹2.5L'`; below 1 lakh falls through to `formatMoney`.
   - `addCommaWithSign(1234.5, currencySymbol: '₹')` uses Indian grouping
     (`isIndianCurrency` matches on symbol '₹' OR code 'INR');
     with `'$'`/USD → `'$1,234.50'` western grouping.
   - **Edge case:** `formatMoney` with default args hides decimals
     (`showDecimals: false`) — assert `'$1,235'` (NumberFormat rounds), not
     `'$1,234'`. Verify actual rounding behavior by running the test, and set
     the expectation to what `NumberFormat.currency` produces — do not guess.
4. **`test/debt_model_test.dart`** for `lib/models/debt.dart`:
   - `getDaysUntilDue` is DATE-only: a due date of *today at 00:01* with a test
     performed later in the day must return 0, not -1. Construct
     `dueDate: DateTime(now.year, now.month, now.day, 0, 1)`.
   - `getProgressPercentage` with `amount: 0` → 0 (no division by zero); clamps
     at 100 when `amountPaid > amount`.
   - `update(...)` with `amountPaid >= amount` → `DebtStatus.paid`; with past
     `dueDate` and partial payment → `DebtStatus.overdue`; with future dueDate →
     `DebtStatus.active`.
   - Round-trip `toMap`/`fromMap` preserves `transactionId` (new column) and a
     null `transactionId` stays null.
5. **`test/goal_model_test.dart`**: mirror of debt basics — progress clamp,
   `isAchieved` at exactly `currentAmount == targetAmount` (the check is `>=`),
   `getDaysUntilTarget` date-only, `toMap/fromMap` round-trip.
6. Inspect `test/widget_test.dart`. If it is the Flutter template counter test
   (`expect(find.text('0'), findsOneWidget)` against `MyApp`), delete the file —
   `MyApp` needs providers/plugins and the test is meaningless here.
   **Do not touch** the four existing AI tests; run `flutter test` and confirm
   they still pass before and after your changes.
7. Run `flutter test` — all green. Run `flutter analyze` — clean.

## Edge cases a weaker model would miss (summary)

- `BudgetProjection` needs the `now` injection refactor FIRST; testing against
  the real clock produces tests that pass today and fail next month.
- Elapsed days = `now.day - 1` (clamped to ≥1), NOT `now.day`.
- The one-time threshold comparison is `>=` and becomes infinity at budget 0.
- sqflite cannot run in plain unit tests — do NOT write tests that touch any
  `*_db_helper.dart` (they'd need `sqflite_common_ffi`; out of scope).
- `Debt.fromMap` expects `status` as an int index — build maps via `toMap()`.

## Acceptance criteria

- [ ] `flutter test` passes with ≥ 25 new test cases across 4 new files
- [ ] `flutter analyze` clean
- [ ] Changing `now.day - 1` to `now.day` in budget_projection.dart makes at
      least one test FAIL (sanity-check the suite bites; revert after)
- [ ] No test file imports any `db/*_db_helper.dart`
