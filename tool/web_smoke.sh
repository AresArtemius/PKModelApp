#!/usr/bin/env bash
set -euo pipefail

base_url="${1:-https://app.pk.management}"
base_url="${base_url%/}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fetch() {
  local path="$1"
  local output="$2"
  curl --fail --silent --show-error --location \
    --retry 10 --retry-delay 3 --retry-all-errors \
    "$base_url$path" --output "$output"
}

ready=false
for attempt in {1..20}; do
  fetch "/" "$tmp_dir/index.html"
  if grep -q '<title>PK Management</title>' "$tmp_dir/index.html" &&
     grep -q 'id="app-loading"' "$tmp_dir/index.html"; then
    ready=true
    break
  fi
  echo "Waiting for the new release at $base_url (attempt $attempt/20)..."
  sleep 5
done

if [ "$ready" != true ]; then
  echo "The deployed release did not become available in time."
  exit 1
fi

fetch "/manifest.json" "$tmp_dir/manifest.json"
grep -q 'PK Management' "$tmp_dir/manifest.json"

fetch "/flutter_bootstrap.js" "$tmp_dir/flutter_bootstrap.js"
fetch "/main.dart.js" "$tmp_dir/main.dart.js"
fetch "/firebase-messaging-sw.js" "$tmp_dir/firebase-messaging-sw.js"

test -s "$tmp_dir/flutter_bootstrap.js"
test -s "$tmp_dir/main.dart.js"
test -s "$tmp_dir/firebase-messaging-sw.js"

echo "Production smoke test passed for $base_url"
