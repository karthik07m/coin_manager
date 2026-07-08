# PLAN: Verify pending work, commit everything, and fix the build environment

**Rank: 1 of 5 — do this first.** All other plans build on top of a working tree
that is currently: (a) partially unverified, (b) 172 files of uncommitted work,
and (c) located in an iCloud-synced folder that has repeatedly corrupted builds.
Until this is done, weeks of work can be lost by a single sync glitch.

## Goal

1. Verify the pending, never-built change in `lib/screens/debt_detail_screen.dart`
   (an account picker was added to the Record Payment sheet; the build was
   interrupted before `flutter analyze` ran).
2. Commit all working-tree changes in logical commits.
3. Relocate the project out of `~/Desktop` (iCloud-synced) to `~/dev/coin_manager`.
4. Add a `tool/verify.sh` script so future changes are gated on analyze + build.

## Exact files to touch

- `lib/screens/debt_detail_screen.dart` — verify only (no edits unless analyzer fails)
- `.gitignore` — verify `build/`, `.dart_tool/` are ignored (file was modified this cycle; read it)
- `tool/verify.sh` — new file
- No other source edits. This plan is process, not features.

## Step-by-step

1. `cd "/Users/manikarthik/Desktop/Coin Manager"`
2. Run `flutter analyze`. If it reports errors in `debt_detail_screen.dart`, fix
   only what the analyzer names (the pending diff adds: `account_provider.dart` /
   `account.dart` imports, an `_accountIcon(Account)` helper, an
   `accountId` named param on `_createSettlementTransaction`, account loading at
   the top of `_showRecordPaymentDialog`, an account-pill `Wrap` in the sheet, and
   `accountId: selectedAccountId` at the submit call). Do NOT revert the diff.
3. Check for iCloud junk files before committing:
   `find . -name "* 2*" -not -path "./build/*" -not -path "./.git/*" -not -path "./.dart_tool/*"`
   Delete any matches (they are iCloud sync duplicates, e.g. `MainActivity 2.kt`).
   **Edge case:** these duplicates have appeared repeatedly in `build/` during
   this project's history; if any exist in `lib/` or `android/` they WILL break
   compilation and MUST NOT be committed.
4. Read `.gitignore` and confirm it ignores `build/`, `.dart_tool/`,
   `*.iml`, `.flutter-plugins*`. Add any that are missing.
5. `flutter clean && flutter pub get && flutter build apk --debug --target-platform android-arm64`
   Must end with `✓ Built`. **Edge case:** if Gradle fails with
   "Type X is defined multiple times" or "duplicate classes", that is iCloud
   corruption, not a code bug — run `flutter clean` and build again.
6. Commit in logical groups (git status is large; use `git add` with explicit paths):
   - Commit A "Debt tracker hardening + relative due dates": `lib/models/debt.dart`,
     `lib/providers/debt_provider.dart`, `lib/screens/debt_form_screen.dart`,
     `lib/screens/debt_list_screen.dart`
   - Commit B "Goals feature": `lib/models/goal.dart`, `lib/models/goal_contribution.dart`,
     `lib/db/goal_db_helper.dart`, `lib/providers/goal_provider.dart`,
     `lib/screens/goal_*.dart`, `lib/widgets/goal_summary_widget.dart`
   - Commit C "Biometric app lock": `lib/services/app_lock_service.dart`,
     `lib/widgets/app_lock_gate.dart`, `android/app/src/main/AndroidManifest.xml`,
     `android/app/src/main/kotlin/com/example/coin_manager/MainActivity.kt`,
     `ios/Runner/Info.plist`, `pubspec.yaml`, `pubspec.lock`
   - Commit D "Keypad-first transaction form + loan flow": `lib/screens/transaction_form.dart`
   - Commit E "Home screen: unified budget projection + upcoming payments list":
     `lib/utilities/budget_projection.dart`, `lib/widgets/quick_stats_widget.dart`,
     `lib/widgets/upcoming_payments_widget.dart`,
     `lib/widgets/budget_expenses_chart_widget.dart`, deletion of
     `lib/widgets/spending_forecast_widget.dart`, `lib/screens/home_scrn.dart`,
     `lib/providers/settings_provider.dart`, `lib/screens/setting.dart`
   - Commit F "Debt ↔ transaction linking": `lib/models/debt_payment.dart`,
     `lib/db/debt_db_helper.dart`, `lib/screens/debt_detail_screen.dart`
   - Commit G: everything remaining (`git add -A` then review `git status` — this
     sweeps onboarding, accent-color refactor across ~19 files, icons, README).
   **Edge case:** the deleted asset files (`assets/mascot*.png`,
   `assets/business_coin_*.png`, `assets/nodata.png`) show as `D` in git status —
   these deletions are intentional; include them in Commit G. Confirm
   `pubspec.yaml`'s assets section no longer references them (it only lists
   `assets/categories/`).
   End every commit message with:
   `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
7. Create `tool/verify.sh` (chmod +x):
   ```bash
   #!/usr/bin/env bash
   set -e
   flutter analyze
   flutter test
   flutter build apk --debug --target-platform android-arm64
   echo "VERIFY OK"
   ```
   **Edge case:** until PLAN-money-math-tests lands, `flutter test` runs the
   existing AI tests plus `test/widget_test.dart`. Run it once; if
   `widget_test.dart` is the stock counter template and fails, delete it in the
   same commit as the script and note why.
8. Relocate: `mkdir -p ~/dev && git clone "/Users/manikarthik/Desktop/Coin Manager" ~/dev/coin_manager`
   (clone, don't `mv` — iCloud may hold locks on the original). Then in
   `~/dev/coin_manager`: `flutter pub get && ./tool/verify.sh`.
   **Edge case:** `git clone` of a local path only copies committed state —
   which is why committing (step 6) must happen first. Copy any untracked-but-
   wanted files manually if `git status` still shows them post-commit.
9. Tell the user to open `~/dev/coin_manager` for all future work and optionally
   archive the Desktop copy.

## Acceptance criteria

- [ ] `flutter analyze` → "No issues found!" in the ORIGINAL folder before committing
- [ ] `git status --porcelain | wc -l` → 0 after step 6
- [ ] `git log --oneline | head -8` shows the logical commits above
- [ ] `find lib android ios -name "* 2*"` returns nothing
- [ ] `~/dev/coin_manager` exists, `./tool/verify.sh` prints `VERIFY OK` there
- [ ] Record Payment sheet on device shows account pills under "Add to transactions" (manual check)
