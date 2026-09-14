# Regional personalization for Coinly

## Goal

Make Coinly useful for Indian households while preserving the same budgeting,
accounts, goals, debts, and recurring-payment features for users everywhere.
INR suggests an optional setup; it never determines nationality or language.

## Release 1 — implementation in this change

1. Add a dismissible “Personalize for India” home card for INR users. Settings
   always exposes regional preferences, including for users of other currencies.
2. Persist India template suggestions and the financial-year start month as
   independent preferences. Save the setup only when the user chooses Save.
   Dismissal persists. Currency changes preserve these choices and the budget rule.
   Existing installs retain their stored budget rules and January–December reports
   until they explicitly select a different reporting year.
   Saving the suggested setup opens the template library immediately.
3. Add a template library accessible in Settings for all currencies. General
   templates cover rent, utilities, subscriptions, emergency savings, and holidays.
   Optional India suggestions add milk bills, domestic help, household groceries,
   loan EMI, school fees, insurance, and festival/family-event savings.
4. Templates open editable transaction/goal forms. They do not create transactions,
   accounts, categories, mandates, or goals until the existing form is saved.
   Users supply amounts, accounts, and dates. Monthly payments use existing
   recurrence/reminder behavior; annual costs use savings goals.
5. Make the yearly expense chart honor any financial-year start month. April–March
   reports span the correct two calendar years. Bar labels and month navigation
   carry the correct year. Preserve currency conversion and exclude transfers.
6. Verify persistence, opt-in/currency independence, template draft behavior,
   year boundaries, chart navigation, and existing money-math behavior. Run static
   analysis and relevant Flutter tests. Existing backup captures all preferences.

## Follow-up releases

These are separate features, not enabled switches or placeholder screens in this
release:

- Salary-to-salary budgets: introduce explicit period keys, migrate calendar-budget
  lookups across home/charts/exports/AI, handle short months and payday changes,
  and reserve unpaid commitments without subtracting posted expenses twice.
- Household khata: daily quantities/rates, corrections, partial settlements,
  outstanding dues, and atomic links to transactions. Add backup migrations and
  reconciliation tests before offering “settle” actions.
- EMI planning: principal/interest breakdown, finite installment schedules,
  per-account forecasts, and early closure. Recurring templates in release 1
  are reminders/transactions, not amortization schedules or bank mandates.
- UPI-aware imports: supported statement samples, reference-based duplicate
  detection, merchant rules, refunds/transfers, and review before import. Any
  automatic bank connection requires its own consent/integration design.
- Language: translate the actual UI and validate text/voice parsers per supported
  language. Language remains independent from country and currency.
- Financial-year exports: add explicit date filtering and period labels to the
  existing Excel export, which currently exports all transactions.

## Acceptance criteria

- INR users can accept or dismiss setup, and revisit it in Settings.
- USD/EUR/GBP/JPY users can use all general features and opt into India templates.
- Switching currencies never resets regional preferences or a chosen budget rule.
- A dismissed prompt stays dismissed after relaunch and currency round-trips.
- Canceling setup or a template form makes no financial records.
- Existing financial records remain accessible when suggestions are disabled.
- March and April, January and December, and leap years map to correct reporting
  windows; tapping a January bar in an April-start year navigates to the next year.

## Validation results

- Implemented release 1. The follow-up releases above remain future work.
- Full Flutter suite: 240 tests passed, including 21 new preference, reporting,
  SQLite aggregation, and widget tests.
- Widget checks cover 360dp screens and the preferences page at 320dp with 1.5×
  text scaling, cancel/dismiss/save behavior, template navigation, and January
  navigation inside an April-start financial year.
- Static analysis: no errors or diagnostics in the feature files. The repository
  retains 10 existing diagnostics in scratch.dart and unrelated import/export/
  backup tests.
- Final targeted analysis of all lib code and the four new test files: no issues.
- Regression coverage includes older installs whose budget rule had not yet
  been persisted: changing currency and restarting preserves that rule too.
- Existing diff whitespace warnings are outside the new feature edits.
- No native device build or bank connection was performed; templates use the
  app's existing recurring-transaction workflow.
