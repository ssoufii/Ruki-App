#!/usr/bin/env bash
# Fails if any feature code calls Date() directly instead of going through
# ClockProviding. CLAUDE.md: "the single most important architectural rule
# in this codebase — all the hard bugs are time bugs."
#
# SystemClock.swift is the one permitted call site (ClockProviding's own
# implementation). Test targets are exempt — FixedClock legitimately
# constructs Date values to pin time in tests.
set -euo pipefail
cd "$(dirname "$0")/.."

VIOLATIONS=$(grep -rn 'Date()' Ruki/ \
  --include='*.swift' \
  | grep -v 'Ruki/Core/Clock/SystemClock.swift' \
  | grep -v 'Ruki/Core/Clock/ClockProviding.swift' \
  | grep -vE '^\S+:[0-9]+:\s*///' \
  || true)

if [ -n "$VIOLATIONS" ]; then
  echo "error: direct Date() call(s) found outside SystemClock.swift — inject ClockProviding instead:"
  echo "$VIOLATIONS"
  exit 1
fi

echo "ok: no direct Date() calls in Ruki/ outside SystemClock.swift"
