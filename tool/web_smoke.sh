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
fetch "/release.json" "$tmp_dir/release.json"
grep -q '"sha":"[0-9a-f]\{40\}"' "$tmp_dir/release.json" || { echo "release.json has no commit sha"; cat "$tmp_dir/release.json"; exit 1; }
fetch "/logo-144.png" "$tmp_dir/logo-144.png"
test -s "$tmp_dir/logo-144.png"
grep -q 'PK Management' "$tmp_dir/manifest.json"

fetch "/flutter_bootstrap.js" "$tmp_dir/flutter_bootstrap.js"
fetch "/main.dart.js" "$tmp_dir/main.dart.js"
fetch "/firebase-messaging-sw.js" "$tmp_dir/firebase-messaging-sw.js"

test -s "$tmp_dir/flutter_bootstrap.js"
test -s "$tmp_dir/main.dart.js"
test -s "$tmp_dir/firebase-messaging-sw.js"

# Renderer must be self-hosted: no Google CDN references in the bootstrap,
# and the CanvasKit files must be served from our own origin.
# (The bootstrap always embeds the gstatic URL as a code fallback; what matters is
# the build flag that makes it load CanvasKit from our origin.)
if ! grep -q '"useLocalCanvasKit":true' "$tmp_dir/flutter_bootstrap.js"; then
  echo "flutter_bootstrap.js was built without --no-web-resources-cdn (useLocalCanvasKit is not true)."
  exit 1
fi
fetch "/canvaskit/canvaskit.js" "$tmp_dir/canvaskit.js"
fetch "/canvaskit/canvaskit.wasm" "$tmp_dir/canvaskit.wasm"
test -s "$tmp_dir/canvaskit.js"
test -s "$tmp_dir/canvaskit.wasm"

echo "Production smoke test passed for $base_url"
