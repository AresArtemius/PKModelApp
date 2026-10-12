#!/usr/bin/env bash
# iOS release build (step 61). Signing is done by Xcode with the account
# set in Runner.xcodeproj (Signing & Capabilities), so this script only
# produces the archive-ready build; open ios/Runner.xcworkspace afterwards
# and Product → Archive, or pass --ipa to export with the ExportOptions.
set -euo pipefail

# Client config: SUPABASE_URL and SUPABASE_ANON_KEY (the public anon key —
# never the secret/service_role key). If they are not in the environment,
# read them from a local, git-ignored file so nothing has to be typed:
#   ~/Documents/pk-keys/supabase.env   (or .env.local in the repo root)
# with two lines:
#   SUPABASE_URL=https://<ref>.supabase.co
#   SUPABASE_ANON_KEY=eyJ...
if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  for f in "$HOME/Documents/pk-keys/supabase.env" "$(dirname "$0")/../.env.local"; do
    if [ -f "$f" ]; then
      # shellcheck disable=SC1090
      set -a; . "$f"; set +a
      echo "Loaded Supabase client config from $f"
      break
    fi
  done
fi
if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "Missing SUPABASE_URL and/or SUPABASE_ANON_KEY." >&2
  echo "Create ~/Documents/pk-keys/supabase.env with those two lines (anon key only)." >&2
  exit 1
fi
case "$SUPABASE_ANON_KEY" in
  sb_secret_*)
    echo "SUPABASE_ANON_KEY looks like a SECRET key (sb_secret_...). Use the anon/publishable key." >&2
    exit 1;;
esac

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
