#!/bin/sh
# Purpose: Verify the startup bootstrap script for the first-install happy path and a clear missing-URL failure.
# Input/Output: Uses isolated temporary directories and stub executables instead of network or real container state.
# Invariants: Tests never download Foundry and never modify any persistent host path.
# Debug: Run `./tests/entrypoint.test.sh`; on failure inspect the temp directory path printed in the logs.

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
ENTRYPOINT_PATH="$ROOT_DIR/docker/entrypoint.sh"
RENDER_OPTIONS_PATH="$ROOT_DIR/docker/render-options.mjs"
DETECT_FOUNDYRY_MAJOR_PATH="$ROOT_DIR/docker/detect-foundry-major.mjs"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

make_stub() {
  stub_path="$1"
  shift
  cat >"$stub_path" <<EOF
$*
EOF
  chmod +x "$stub_path"
}

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

export PATH="$TMP_DIR/bin:$PATH"
mkdir -p "$TMP_DIR/bin"

# Why this exists: The bootstrap test needs deterministic stand-ins for curl, unzip, and the final Foundry node process.
make_stub "$TMP_DIR/bin/curl" '#!/bin/sh
set -eu
output=""
last=""
for arg in "$@"; do
  if [ "$last" = "--output" ]; then
    output="$arg"
  fi
  last="$arg"
done
[ -n "$output" ] || exit 9
printf "fake archive" >"$output"
'

make_stub "$TMP_DIR/bin/unzip" '#!/bin/sh
set -eu
archive=""
target=""
last=""
for arg in "$@"; do
  if [ "$last" = "-d" ]; then
    target="$arg"
  fi
  case "$arg" in
    -*)
      ;;
    *)
      if [ -z "$archive" ]; then
        archive="$arg"
      fi
      ;;
  esac
  last="$arg"
done
mkdir -p "$target"
printf "console.log(\"fake foundry\");\n" >"$target/main.js"
cat >"$target/package.json" <<EOF
{
  "version": "14.359"
}
EOF
'

make_stub "$TMP_DIR/bin/foundry-node22" '#!/bin/sh
set -eu
{
  printf "runtime=node22\n"
  printf "%s\n" "$@"
} >"${ENTRYPOINT_CAPTURE_FILE:?}"
'

make_stub "$TMP_DIR/bin/foundry-node24" '#!/bin/sh
set -eu
{
  printf "runtime=node24\n"
  printf "%s\n" "$@"
} >"${ENTRYPOINT_CAPTURE_FILE:?}"
'

app_dir="$TMP_DIR/runtime/app"
data_dir="$TMP_DIR/runtime/userdata"
cache_dir="$TMP_DIR/runtime/cache"
mkdir -p "$app_dir" "$data_dir" "$cache_dir"

# Why this exists: Missing download information is the most common first-start mistake and should be obvious.
if env \
  LOG_LEVEL=debug \
  FOUNDRY_ROOT="$TMP_DIR/runtime" \
  FOUNDRY_APP_PATH="$app_dir" \
  FOUNDRY_DATA_PATH="$data_dir" \
  FOUNDRY_CACHE_PATH="$cache_dir" \
  RENDER_OPTIONS_SCRIPT="$RENDER_OPTIONS_PATH" \
  DETECT_FOUNDRY_MAJOR_SCRIPT="$DETECT_FOUNDYRY_MAJOR_PATH" \
  FOUNDRY_NODE22_BIN="$TMP_DIR/bin/foundry-node22" \
  FOUNDRY_NODE24_BIN="$TMP_DIR/bin/foundry-node24" \
  HOST_NODE_BIN=node \
  sh "$ENTRYPOINT_PATH" >"$TMP_DIR/missing.stdout" 2>"$TMP_DIR/missing.stderr"; then
  printf "Expected bootstrap without FOUNDRY_RELEASE_URL to fail, but it succeeded.\n" >&2
  exit 1
fi

assert_contains "$TMP_DIR/missing.stderr" "FOUNDRY_RELEASE_URL is required"

# Why this exists: Happy path proves the script installs the app, writes options.json, and assembles the correct launch args.
capture_file="$TMP_DIR/foundry-args.txt"
export ENTRYPOINT_CAPTURE_FILE="$capture_file"

env \
  LOG_LEVEL=debug \
  FOUNDRY_RELEASE_URL=https://example.invalid/foundry-node.zip \
  FOUNDRY_ADMIN_KEY=test-admin-key \
  FOUNDRY_WORLD=my-world \
  FOUNDRY_ROOT="$TMP_DIR/runtime" \
  FOUNDRY_APP_PATH="$app_dir" \
  FOUNDRY_DATA_PATH="$data_dir" \
  FOUNDRY_CACHE_PATH="$cache_dir" \
  FOUNDRY_PROXY_SSL=true \
  FOUNDRY_PROXY_PORT=443 \
  FOUNDRY_HOSTNAME=vtt.example.test \
  FOUNDRY_ROUTE_PREFIX=/foundry/ \
  RENDER_OPTIONS_SCRIPT="$RENDER_OPTIONS_PATH" \
  DETECT_FOUNDRY_MAJOR_SCRIPT="$DETECT_FOUNDYRY_MAJOR_PATH" \
  FOUNDRY_NODE22_BIN="$TMP_DIR/bin/foundry-node22" \
  FOUNDRY_NODE24_BIN="$TMP_DIR/bin/foundry-node24" \
  HOST_NODE_BIN=node \
  sh "$ENTRYPOINT_PATH" >"$TMP_DIR/happy.stdout" 2>"$TMP_DIR/happy.stderr"

assert_contains "$capture_file" "runtime=node24"
assert_contains "$capture_file" "$app_dir/main.js"
assert_contains "$capture_file" "--dataPath=$data_dir"
assert_contains "$capture_file" "--port=30000"
assert_contains "$capture_file" "--world=my-world"
assert_contains "$capture_file" "--adminPassword=test-admin-key"
assert_contains "$capture_file" "--noupnp"
assert_contains "$data_dir/Config/options.json" '"hostname": "vtt.example.test"'
assert_contains "$data_dir/Config/options.json" '"proxySSL": true'
assert_contains "$data_dir/Config/options.json" '"proxyPort": 443'
assert_contains "$data_dir/Config/options.json" '"routePrefix": "foundry"'

# Why this exists: Foundry 13.x needs the Node 22 runtime profile, and auto-detection should choose it from the installed app metadata.
legacy_app_dir="$TMP_DIR/runtime-v13/app"
legacy_data_dir="$TMP_DIR/runtime-v13/userdata"
legacy_cache_dir="$TMP_DIR/runtime-v13/cache"
mkdir -p "$legacy_app_dir" "$legacy_data_dir" "$legacy_cache_dir"
cat >"$legacy_app_dir/main.js" <<'EOF'
console.log("fake foundry v13");
EOF
cat >"$legacy_app_dir/package.json" <<'EOF'
{
  "version": "13.351"
}
EOF

legacy_capture_file="$TMP_DIR/foundry-v13-args.txt"
export ENTRYPOINT_CAPTURE_FILE="$legacy_capture_file"

env \
  LOG_LEVEL=debug \
  FOUNDRY_ROOT="$TMP_DIR/runtime-v13" \
  FOUNDRY_APP_PATH="$legacy_app_dir" \
  FOUNDRY_DATA_PATH="$legacy_data_dir" \
  FOUNDRY_CACHE_PATH="$legacy_cache_dir" \
  RENDER_OPTIONS_SCRIPT="$RENDER_OPTIONS_PATH" \
  DETECT_FOUNDRY_MAJOR_SCRIPT="$DETECT_FOUNDYRY_MAJOR_PATH" \
  FOUNDRY_NODE22_BIN="$TMP_DIR/bin/foundry-node22" \
  FOUNDRY_NODE24_BIN="$TMP_DIR/bin/foundry-node24" \
  HOST_NODE_BIN=node \
  sh "$ENTRYPOINT_PATH" >"$TMP_DIR/v13.stdout" 2>"$TMP_DIR/v13.stderr"

assert_contains "$legacy_capture_file" "runtime=node22"
assert_contains "$legacy_capture_file" "$legacy_app_dir/main.js"

printf "entrypoint tests passed.\n"
