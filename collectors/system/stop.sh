#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

PROJECT_ROOT="$(cd ../.. && pwd)"
PIDFILE="$PROJECT_ROOT/.telegraf.pid"

if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE")
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    echo "Telegraf stopped (PID $PID)"
  else
    echo "Telegraf not running (stale PID file)"
  fi
  rm -f "$PIDFILE"
else
  echo "Telegraf not running (no PID file)"
fi
