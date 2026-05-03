#!/bin/sh
# Purpose: Verify that Foundry major version detection works for both root and legacy package.json locations.
# Input/Output: Uses temporary files only and exits non-zero if an assertion fails.
# Invariants: The test never touches real Foundry installs.
# Debug: Run `./tests/detect-foundry-major.test.sh` and inspect the temporary directory on failure.

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/docker/detect-foundry-major.mjs"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

assert_equals() {
  expected="$1"
  actual="$2"

  if [ "$expected" != "$actual" ]; then
    printf "Assertion failed. Expected '%s' but got '%s'.\n" "$expected" "$actual" >&2
    exit 1
  fi
}

# Why this exists: Modern Foundry node builds store package.json at the app root.
modern_dir="$TMP_DIR/modern"
mkdir -p "$modern_dir"
cat >"$modern_dir/package.json" <<'EOF'
{
  "version": "14.359"
}
EOF

modern_major="$(node "$SCRIPT_PATH" "$modern_dir")"
assert_equals "14" "$modern_major"

# Why this exists: Older layouts can keep package.json under resources/app.
legacy_dir="$TMP_DIR/legacy/resources/app"
mkdir -p "$legacy_dir"
cat >"$legacy_dir/package.json" <<'EOF'
{
  "version": "13.351"
}
EOF

legacy_major="$(node "$SCRIPT_PATH" "$TMP_DIR/legacy")"
assert_equals "13" "$legacy_major"

printf "detect-foundry-major tests passed.\n"
