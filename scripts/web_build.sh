#!/usr/bin/env bash
set -euo pipefail

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "Missing required env vars: SUPABASE_URL and/or SUPABASE_ANON_KEY" >&2
  exit 1
fi

export PATH="$HOME/flutter/bin:$PATH"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found. Installing stable Flutter into $HOME/flutter..."
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

flutter --version
flutter config --enable-web
flutter pub get
flutter build web   --release   --pwa-strategy=none   --dart-define=SUPABASE_URL="$SUPABASE_URL"   --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
