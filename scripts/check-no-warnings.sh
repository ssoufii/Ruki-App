#!/usr/bin/env bash
# Fails if an xcodebuild log contains compiler warnings. Xcode's own
# "AppIntents metadata extraction skipped" tool notice is not a code warning.
set -euo pipefail
LOG="${1:?usage: check-no-warnings.sh <xcodebuild.log>}"
FOUND=$(grep -E 'warning:' "$LOG" | grep -v 'AppIntents' | sort -u || true)
if [ -n "$FOUND" ]; then
  echo "error: compiler warning(s) found in $LOG:"
  echo "$FOUND"
  exit 1
fi
echo "ok: no compiler warnings in $LOG"
