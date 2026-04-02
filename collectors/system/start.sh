#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

PROJECT_ROOT="$(cd ../.. && pwd)"
source "$PROJECT_ROOT/.env"

# Auto-install Telegraf if not present
if ! command -v telegraf &>/dev/null; then
  echo "Telegraf not found. Installing via Homebrew..."
  brew install telegraf
fi

# Export vars for Telegraf env substitution
export INFLUXDB_TOKEN INFLUXDB_ORG INFLUXDB_BUCKET
export SYSTEM_COLLECT_INTERVAL="${SYSTEM_COLLECT_INTERVAL:-30s}"
export SYSTEM_COLLECTOR_DIR="$PWD"

PIDFILE="$PROJECT_ROOT/.telegraf.pid"
LOGFILE="$PROJECT_ROOT/logs/telegraf.log"

# Check if already running
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "Telegraf already running (PID $(cat "$PIDFILE"))"
  exit 0
fi

mkdir -p "$(dirname "$LOGFILE")"

telegraf --config "$PWD/telegraf.conf" >> "$LOGFILE" 2>&1 &
echo $! > "$PIDFILE"
echo "Telegraf started (PID $!, log: logs/telegraf.log)"
