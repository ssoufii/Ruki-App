#!/bin/bash
# Starts the Ruki dev server, first stopping any earlier copy holding the port.
#   scripts/dev-server.sh            start (keeps accounts and check-ins)
#   scripts/dev-server.sh --reset    wipe server/data first (accounts, friends, photos)
# Only ever stops a process that is running ruki_server.py.
set -e
cd "$(dirname "$0")/.."
PORT="${PORT:-8080}"

OLD=$(lsof -ti tcp:"$PORT" -sTCP:LISTEN 2>/dev/null | head -1 || true)
if [ -n "$OLD" ]; then
  if ps -p "$OLD" -o command= | grep -q ruki_server.py; then
    echo "Stopping the earlier Ruki server (pid $OLD)…"
    kill "$OLD"
    sleep 1
  else
    echo "Port $PORT is used by something that isn't the Ruki server (pid $OLD). Leaving it alone." >&2
    exit 1
  fi
fi

if [ "${1:-}" = "--reset" ]; then
  echo "Resetting server/data…"
  rm -rf server/data
fi

exec python3 server/ruki_server.py
