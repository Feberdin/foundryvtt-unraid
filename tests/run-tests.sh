#!/bin/sh
# Purpose: Run all lightweight local tests for the Foundry Docker bootstrap repository.
# Input/Output: Executes the repository test scripts and exits non-zero if any test fails.
# Invariants: Tests stay local and do not require Docker or network access.
# Debug: Run individual scripts in ./tests if you need a narrower failure signal.

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

# Why this exists: A single entry point is easier for non-programmers than remembering several test commands.
"$ROOT_DIR/tests/render-options.test.sh"
"$ROOT_DIR/tests/entrypoint.test.sh"

printf "All tests passed.\n"
