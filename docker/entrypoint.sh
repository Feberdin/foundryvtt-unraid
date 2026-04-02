#!/bin/sh
# Purpose: Validate the runtime environment, install Foundry from an official timed URL when needed, and launch the Node.js server.
# Input/Output: Reads Docker env vars and persistent directories under /data/foundryvtt, writes app files, config, and logs.
# Invariants: The image never bundles Foundry itself, secrets are never logged, and user data stays separate from application files.
# Debug: Run with LOG_LEVEL=debug and inspect container logs plus userdata/Config/options.json.

set -eu

SCRIPT_NAME="$(basename "$0")"
RENDER_OPTIONS_SCRIPT="${RENDER_OPTIONS_SCRIPT:-/usr/local/lib/foundry/render-options.mjs}"
HOST_NODE_BIN="${HOST_NODE_BIN:-node}"
FOUNDRY_NODE_BIN="${FOUNDRY_NODE_BIN:-node}"

# Why this exists: Simple level handling keeps logs helpful without depending on external tooling.
timestamp() {
  date -u "+%Y-%m-%dT%H:%M:%SZ"
}

level_to_int() {
  case "$1" in
    debug) echo 10 ;;
    info) echo 20 ;;
    warn) echo 30 ;;
    error) echo 40 ;;
    *) echo 20 ;;
  esac
}

log() {
  level="$1"
  shift
  current_level="${LOG_LEVEL:-info}"

  if [ "$(level_to_int "$level")" -ge "$(level_to_int "$current_level")" ]; then
    printf "%s [%s] %s: %s\n" "$(timestamp)" "$level" "$SCRIPT_NAME" "$*" >&2
  fi
}

fail() {
  log error "$*"
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command '$1'. Rebuild the image or verify the PATH."
}

bool_is_true() {
  normalized="$(printf "%s" "${1:-}" | tr "[:upper:]" "[:lower:]")"
  case "$normalized" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

read_secret_file() {
  variable_name="$1"
  file_variable_name="${variable_name}_FILE"
  eval "file_path=\${$file_variable_name:-}"
  eval "current_value=\${$variable_name:-}"

  if [ -z "$file_path" ]; then
    return 0
  fi

  [ -r "$file_path" ] || fail "Secret file '$file_path' for $variable_name is not readable."
  [ -z "$current_value" ] || fail "Use either $variable_name or $file_variable_name, not both."

  secret_value="$(cat "$file_path")"
  export "${variable_name}=${secret_value}"
}

validate_absolute_path() {
  variable_name="$1"
  variable_value="$2"

  case "$variable_value" in
    /*) ;;
    *) fail "$variable_name must be an absolute path inside the container. Current value: '$variable_value'." ;;
  esac
}

validate_numeric_range() {
  label="$1"
  value="$2"
  minimum="$3"
  maximum="$4"

  case "$value" in
    *[!0-9]*|"") fail "$label must be a whole number. Current value: '$value'." ;;
  esac

  if [ "$value" -lt "$minimum" ] || [ "$value" -gt "$maximum" ]; then
    fail "$label must be between $minimum and $maximum. Current value: '$value'."
  fi
}

normalize_route_prefix() {
  route_prefix="${FOUNDRY_ROUTE_PREFIX:-}"
  route_prefix="${route_prefix#/}"
  route_prefix="${route_prefix%/}"
  export "FOUNDRY_ROUTE_PREFIX=${route_prefix}"
}

prepare_directories() {
  mkdir -p \
    "$FOUNDRY_ROOT" \
    "$FOUNDRY_APP_PATH" \
    "$FOUNDRY_DATA_PATH" \
    "$FOUNDRY_DATA_PATH/Config" \
    "$FOUNDRY_DATA_PATH/Data" \
    "$FOUNDRY_DATA_PATH/Logs" \
    "$FOUNDRY_CACHE_PATH"
}

safe_empty_directory() {
  target_dir="$1"

  case "$target_dir" in
    ""|"/"|"/data"|"/data/"|"/data/foundryvtt"|"/data/foundryvtt/")
      fail "Refusing to delete unsafe directory target '$target_dir'."
      ;;
  esac

  if [ -d "$target_dir" ]; then
    find "$target_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  fi
}

install_foundry_if_needed() {
  archive_path="$FOUNDRY_CACHE_PATH/foundryvtt.zip"

  if [ -f "$FOUNDRY_APP_PATH/main.js" ] && ! bool_is_true "${FOUNDRY_FORCE_REINSTALL:-false}"; then
    log info "Foundry application files already exist in $FOUNDRY_APP_PATH. Skipping download."
    return 0
  fi

  if [ -f "$FOUNDRY_APP_PATH/resources/app/main.js" ] && ! bool_is_true "${FOUNDRY_FORCE_REINSTALL:-false}"; then
    log info "Foundry legacy application files already exist in $FOUNDRY_APP_PATH. Skipping download."
    return 0
  fi

  [ -n "${FOUNDRY_RELEASE_URL:-}" ] || fail "FOUNDRY_RELEASE_URL is required for the first install or when FOUNDRY_FORCE_REINSTALL=true. Generate a fresh Node.js timed URL in the Foundry website and restart the container within a few minutes."

  if bool_is_true "${FOUNDRY_FORCE_REINSTALL:-false}"; then
    log warn "FOUNDRY_FORCE_REINSTALL=true. Existing application files in $FOUNDRY_APP_PATH will be replaced."
    safe_empty_directory "$FOUNDRY_APP_PATH"
  fi

  log info "Downloading Foundry from the official timed URL. The URL itself is intentionally not logged."
  if ! curl --fail --location --silent --show-error "$FOUNDRY_RELEASE_URL" --output "$archive_path"; then
    fail "Foundry download failed. The most common cause is an expired timed URL. Generate a new Node.js timed URL in the Foundry portal and retry immediately."
  fi

  log info "Extracting the Foundry archive into $FOUNDRY_APP_PATH."
  if ! unzip -oq "$archive_path" -d "$FOUNDRY_APP_PATH"; then
    fail "The Foundry archive could not be extracted. Verify that the URL points to a valid Node.js ZIP and that the app path is writable."
  fi

  rm -f "$archive_path"

  if [ ! -f "$FOUNDRY_APP_PATH/main.js" ] && [ ! -f "$FOUNDRY_APP_PATH/resources/app/main.js" ]; then
    fail "The extracted archive does not contain a Foundry entrypoint. For Version 13+ select the Node.js build. For older releases use the Linux build."
  fi
}

write_options_json() {
  options_path="$FOUNDRY_DATA_PATH/Config/options.json"

  log info "Writing managed Foundry settings to $options_path."
  "$HOST_NODE_BIN" "$RENDER_OPTIONS_SCRIPT" "$options_path"
}

fix_permissions_if_needed() {
  if [ "$(id -u)" -ne 0 ]; then
    log debug "Container is not running as root. Skipping ownership correction."
    return 0
  fi

  log info "Ensuring ownership on $FOUNDRY_ROOT matches ${PUID}:${PGID}."
  chown -R "${PUID}:${PGID}" "$FOUNDRY_ROOT"
}

pick_launch_script() {
  if [ -f "$FOUNDRY_APP_PATH/main.js" ]; then
    printf "%s" "$FOUNDRY_APP_PATH/main.js"
    return 0
  fi

  if [ -f "$FOUNDRY_APP_PATH/resources/app/main.js" ]; then
    printf "%s" "$FOUNDRY_APP_PATH/resources/app/main.js"
    return 0
  fi

  fail "Foundry launch script not found after installation. Inspect $FOUNDRY_APP_PATH for an incomplete install."
}

start_foundry() {
  launch_script="$(pick_launch_script)"

  # Why this exists: Command line flags override persisted settings for the pieces that must remain correct inside the container.
  set -- \
    "$launch_script" \
    "--dataPath=$FOUNDRY_DATA_PATH" \
    "--port=$FOUNDRY_PORT"

  if [ -n "${FOUNDRY_WORLD:-}" ]; then
    set -- "$@" "--world=$FOUNDRY_WORLD"
  fi

  if ! bool_is_true "${FOUNDRY_UPNP:-false}"; then
    set -- "$@" "--noupnp"
  fi

  if bool_is_true "${FOUNDRY_DISABLE_UPDATES:-false}"; then
    set -- "$@" "--noupdate"
  fi

  if bool_is_true "${FOUNDRY_DISABLE_IP_DISCOVERY:-false}"; then
    set -- "$@" "--noipdiscovery"
  fi

  if [ -n "${FOUNDRY_ADMIN_KEY:-}" ]; then
    set -- "$@" "--adminPassword=$FOUNDRY_ADMIN_KEY"
  fi

  if [ -n "${FOUNDRY_LOG_SIZE:-}" ]; then
    set -- "$@" "--logsize=$FOUNDRY_LOG_SIZE"
  fi

  if [ -n "${FOUNDRY_MAX_LOGS:-}" ]; then
    set -- "$@" "--maxlogs=$FOUNDRY_MAX_LOGS"
  fi

  log info "Starting Foundry with port=$FOUNDRY_PORT, data_path=$FOUNDRY_DATA_PATH, app_path=$FOUNDRY_APP_PATH, route_prefix=${FOUNDRY_ROUTE_PREFIX:-<none>}, proxy_ssl=${FOUNDRY_PROXY_SSL:-false}, hostname=${FOUNDRY_HOSTNAME:-<none>}."

  if [ "$(id -u)" -eq 0 ]; then
    exec gosu "${PUID}:${PGID}" "$FOUNDRY_NODE_BIN" "$@"
  fi

  exec "$FOUNDRY_NODE_BIN" "$@"
}

# Why this exists: All validations happen before any destructive or external action, so failures are quick and actionable.
read_secret_file "FOUNDRY_RELEASE_URL"
read_secret_file "FOUNDRY_ADMIN_KEY"

FOUNDRY_ROOT="${FOUNDRY_ROOT:-/data/foundryvtt}"
FOUNDRY_APP_PATH="${FOUNDRY_APP_PATH:-$FOUNDRY_ROOT/app}"
FOUNDRY_DATA_PATH="${FOUNDRY_DATA_PATH:-$FOUNDRY_ROOT/userdata}"
FOUNDRY_CACHE_PATH="${FOUNDRY_CACHE_PATH:-$FOUNDRY_ROOT/cache}"
FOUNDRY_PORT="${FOUNDRY_PORT:-30000}"
PUID="${PUID:-99}"
PGID="${PGID:-100}"

export FOUNDRY_ROOT FOUNDRY_APP_PATH FOUNDRY_DATA_PATH FOUNDRY_CACHE_PATH FOUNDRY_PORT PUID PGID

validate_absolute_path "FOUNDRY_ROOT" "$FOUNDRY_ROOT"
validate_absolute_path "FOUNDRY_APP_PATH" "$FOUNDRY_APP_PATH"
validate_absolute_path "FOUNDRY_DATA_PATH" "$FOUNDRY_DATA_PATH"
validate_absolute_path "FOUNDRY_CACHE_PATH" "$FOUNDRY_CACHE_PATH"
validate_numeric_range "FOUNDRY_PORT" "$FOUNDRY_PORT" 1 65535
validate_numeric_range "PUID" "$PUID" 0 65535
validate_numeric_range "PGID" "$PGID" 0 65535

if [ -n "${FOUNDRY_PROXY_PORT:-}" ]; then
  validate_numeric_range "FOUNDRY_PROXY_PORT" "$FOUNDRY_PROXY_PORT" 1 65535
fi

normalize_route_prefix

require_command "curl"
require_command "unzip"
require_command "$HOST_NODE_BIN"
require_command "$FOUNDRY_NODE_BIN"

[ -r "$RENDER_OPTIONS_SCRIPT" ] || fail "Cannot read render script at '$RENDER_OPTIONS_SCRIPT'. Rebuild the image or override RENDER_OPTIONS_SCRIPT for testing."

prepare_directories
install_foundry_if_needed
write_options_json
fix_permissions_if_needed
start_foundry
