#!/bin/sh
# Purpose: Verify that the options renderer writes valid JSON, preserves user settings, and fails cleanly on broken input.
# Input/Output: Uses temporary files only and exits non-zero if an assertion fails.
# Invariants: Tests never touch real Foundry data directories.
# Debug: Run `./tests/render-options.test.sh` and inspect the temporary directory printed on failure.

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/docker/render-options.mjs"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

# Why this exists: Small helpers keep the assertions readable for shell users.
assert_contains() {
  file_path="$1"
  expected_text="$2"

  if ! grep -F -- "$expected_text" "$file_path" >/dev/null 2>&1; then
    printf "Assertion failed. Expected to find '%s' in %s\n" "$expected_text" "$file_path" >&2
    printf "Actual content:\n" >&2
    cat "$file_path" >&2
    exit 1
  fi
}

run_renderer() {
  output_path="$1"
  shift
  env "$@" node "$SCRIPT_PATH" "$output_path"
}

# Why this exists: Happy path proves that fresh config files get the managed values in the expected format.
fresh_output="$TMP_DIR/fresh-options.json"
run_renderer \
  "$fresh_output" \
  FOUNDRY_DATA_PATH=/data/foundryvtt/userdata \
  FOUNDRY_PORT=30000 \
  FOUNDRY_UPNP=false \
  FOUNDRY_PROXY_SSL=true \
  FOUNDRY_PROXY_PORT=443 \
  FOUNDRY_ROUTE_PREFIX=/foundry/

assert_contains "$fresh_output" '"dataPath": "/data/foundryvtt/userdata"'
assert_contains "$fresh_output" '"port": 30000'
assert_contains "$fresh_output" '"upnp": false'
assert_contains "$fresh_output" '"proxySSL": true'
assert_contains "$fresh_output" '"proxyPort": 443'
assert_contains "$fresh_output" '"routePrefix": "foundry"'

# Why this exists: Existing unmanaged values should survive updates so container restarts do not wipe user tweaks.
preserved_output="$TMP_DIR/preserved-options.json"
cat >"$preserved_output" <<'EOF'
{
  "language": "de",
  "hostname": "old.example.test",
  "customFlag": "keep-me"
}
EOF

run_renderer \
  "$preserved_output" \
  FOUNDRY_DATA_PATH=/srv/foundry/userdata \
  FOUNDRY_PORT=30001 \
  FOUNDRY_HOSTNAME=vtt.example.test

assert_contains "$preserved_output" '"language": "de"'
assert_contains "$preserved_output" '"customFlag": "keep-me"'
assert_contains "$preserved_output" '"hostname": "vtt.example.test"'
assert_contains "$preserved_output" '"port": 30001'

# Why this exists: Broken JSON must fail loudly so operators fix the real cause instead of starting with silent damage.
broken_output="$TMP_DIR/broken-options.json"
printf '{ "broken": }\n' >"$broken_output"

if node "$SCRIPT_PATH" "$broken_output" >"$TMP_DIR/broken.stdout" 2>"$TMP_DIR/broken.stderr"; then
  printf "Expected invalid JSON test to fail, but it succeeded.\n" >&2
  exit 1
fi

assert_contains "$TMP_DIR/broken.stderr" "invalid JSON"

printf "render-options tests passed.\n"
