#!/bin/sh
# Purpose: Confirm that the Foundry HTTP endpoint responds inside the container.
# Input/Output: Reads port and route-prefix env vars, exits 0 on success and non-zero on failure.
# Invariants: The check stays local to 127.0.0.1 and never reaches external hosts.
# Debug: Run this script manually inside the container or use `docker inspect --format '{{json .State.Health}}' <container>`.

set -eu

# Why this exists: The healthcheck must follow redirects because Foundry may send `/` to setup or login pages.
port="${FOUNDRY_PORT:-30000}"
scheme="${FOUNDRY_HEALTHCHECK_SCHEME:-http}"
route_prefix="${FOUNDRY_ROUTE_PREFIX:-}"
route_prefix="${route_prefix#/}"
route_prefix="${route_prefix%/}"

if [ -n "$route_prefix" ]; then
  health_url="${scheme}://127.0.0.1:${port}/${route_prefix}/"
else
  health_url="${scheme}://127.0.0.1:${port}/"
fi

if [ "$scheme" = "https" ]; then
  curl --fail --silent --show-error --location --insecure --max-time 5 "$health_url" >/dev/null
else
  curl --fail --silent --show-error --location --max-time 5 "$health_url" >/dev/null
fi
