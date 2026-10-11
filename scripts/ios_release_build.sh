#!/usr/bin/env bash
# iOS release build (step 61). Signing is done by Xcode with the account
# set in Runner.xcodeproj (Signing & Capabilities), so this script only
# produces the archive-ready build; open ios/Runner.xcworkspace afterwards
# and Product → Archive, or pass --ipa to export with the ExportOptions.
set -euo pipefail

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "Missing required env vars: SUPABASE_URL and/or SUPABASE_ANON_KEY" >&2
  exit 1
fi

mode="${1:-}"
if [ "$mode" = "--ipa" ]; then
  # Builds and exports an .ipa for App Store Connect / TestFlight.
  flutter build ipa \
    --release \
    --export-options-plist=ios/ExportOptions.plist \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
  echo "IPA: build/ios/ipa/"
else
  flutter build ios \
    --release \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
  echo "Now: open ios/Runner.xcworkspace → Product → Archive → Distribute App."
fi
