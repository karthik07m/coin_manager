#!/usr/bin/env bash
# Verification gate: run before committing or shipping.
# Catches analyzer errors, test regressions, and the iCloud-sync build
# corruption this project has suffered from (duplicate " 2" files).
set -e
cd "$(dirname "$0")/.."

junk=$(find lib android/app/src ios/Runner test \( -name "* 2" -o -name "* 2.*" \) 2>/dev/null || true)
if [ -n "$junk" ]; then
  echo "ERROR: iCloud duplicate files found — delete before building:"
  echo "$junk"
  exit 1
fi

flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
echo "VERIFY OK"
