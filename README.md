# Coinly: Budget & Expense Tracker

Coinly is a private, offline-first budget and expense tracker for Android, built with Flutter. Financial records are stored on the device; data leaves the phone only when the user turns on a cloud feature (the AI assistant or Google Drive backup).

- Google Play: https://play.google.com/store/apps/details?id=com.budget.coinly
- Website and privacy policy: https://karthik07m.github.io/coinly/

## Features

- **Accounts:** cash, bank and credit card accounts, transfers, live balances, multi-currency with base-currency totals
- **Transactions:** income and expenses with categories, receipts, search and filters, CSV/Excel import and export
- **Budgets and charts:** monthly and category budgets, spending pace and projections, category and account charts, calendar view
- **Recurring and bills:** recurring income and payments with bill reminders
- **Debts and goals:** money owed and owed to you, savings goals with progress
- **Receipt scanning:** on-device text recognition (Google ML Kit)
- **AI assistant:** an on-device parser handles common phrases ("coffee 150", "how's my budget?"); anything else goes to a cloud function running Claude, which returns a draft the user confirms
- **Backup:** local ZIP backups and optional Google Drive backup (`drive.file` scope, only files the app creates)
- **Security and personalization:** app lock (biometrics/passcode), light/dark themes, Material You colors, regional formats (including lakh/crore grouping)

## Tech stack

| Area | Choice |
|---|---|
| App | Flutter 3.32 / Dart 3.8, `provider` for state |
| Storage | SQLite (`sqflite`) on device |
| Charts | `fl_chart` |
| Cloud AI | Supabase Edge Function (`supabase/functions/finance-ai`) calling Claude Sonnet 5 |
| AI allowance | Anonymous Supabase Auth user per install, monthly credits in Postgres |
| Backup | Google Sign-In + Google Drive API |

## Project structure

```
lib/
  main.dart           app entry, routes, providers
  db/                 SQLite helpers
  models/             data models
  providers/          app state (settings, transactions, accounts, AI assistant, ...)
  screens/            UI screens
  services/           backup, import/export, AI parsing and summaries, notifications, receipts, ...
  utilities/          constants, colors, money/date formatting
  widgets/            reusable UI components
test/                 unit and widget tests
supabase/
  config.toml                     function settings (verify_jwt)
  functions/finance-ai/index.ts   cloud AI function
  migrations/                     database schema (monthly AI credits)
tool/
  verify.sh                       analyze + test + debug build gate
  ai_suite.py                     graded end-to-end test of the deployed AI function
  generate_coinly_android_icon.py app icon generation
website/              copy of the marketing site (the live site is maintained separately)
docs/                 design review notes
PRIVACY_POLICY.md     privacy policy (mirrors the website version)
```

## Getting started

Requirements: Flutter 3.32+ (Dart 3.8+), Android SDK, and a device or emulator.

```bash
flutter pub get
flutter run
```

The app works fully offline without any cloud setup. The AI assistant falls back to the on-device parser when the cloud function is unreachable.

### Configuration

The cloud AI endpoint and the Supabase public anon key are built in with defaults and can be overridden at build time:

```bash
flutter run --dart-define=AI_FUNCTION_URL=https://<project>.supabase.co/functions/v1/finance-ai \
            --dart-define=SUPABASE_ANON_KEY=<anon key>
```

The anon key is public by design; the function authenticates each install as an anonymous Supabase user.

## Testing

```bash
flutter analyze
flutter test
```

`tool/verify.sh` runs both plus a debug APK build, and fails early if iCloud duplicate files (`name 2.dart`) are present.

`tool/ai_suite.py` sends 15 difficult messages (lakh amounts, Hinglish, relative dates, prompt injection, summaries) to the **deployed** AI function and grades the replies. It calls Claude and costs roughly $0.10 per run:

```bash
python3 tool/ai_suite.py            # one pass
python3 tool/ai_suite.py --runs 2   # two passes
```

## Cloud AI backend (Supabase)

The `finance-ai` Edge Function turns a message into a transaction draft or summary request. It:

1. confirms the caller's anonymous Supabase session,
2. uses one monthly credit (`consume_ai_credit`, default 100 per user per month),
3. calls Claude and validates the JSON reply before returning it.

Setup:

```bash
supabase link --project-ref <project-ref>
supabase db push                                   # applies migrations
supabase secrets set ANTHROPIC_API_KEY=<key>       # required
supabase secrets set AI_MONTHLY_LIMIT=100          # optional, default 100
supabase functions deploy finance-ai
```

Also enable **Authentication → Sign In / Providers → Allow anonymous sign-ins** in the Supabase dashboard. `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are provided to the function automatically.

## Release build

Release signing reads `android/key.properties` (not committed) pointing at the upload keystore:

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=<alias>
storeFile=<path to upload-keystore.jks>
```

```bash
flutter build appbundle --release
```

Never commit `key.properties` or the keystore; both are ignored by git.

## Notes

- If the project sits in an iCloud-synced folder (such as `~/Desktop`), iCloud can create `name 2` copies and damage build caches and `.git` objects. Run `flutter clean` before verifying a change on a device, and `git fsck` if git reports unreadable objects.

## Privacy

See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) or the published policy at https://karthik07m.github.io/coinly/privacy.html.
