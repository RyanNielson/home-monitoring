#!/usr/bin/env bash
# Collects macOS power/battery metrics and outputs InfluxDB line protocol.
# Used by Telegraf's exec input plugin.

output=$(pmset -g batt 2>/dev/null)

# Exit silently if pmset is unavailable (not macOS)
[ $? -ne 0 ] && exit 0

# Check if running on AC or battery
if echo "$output" | grep -q "AC Power"; then
  ac_power=1
else
  ac_power=0
fi

# Parse battery line: "InternalBattery-0 (id=...)  85%; charging; 1:23 remaining"
battery_line=$(echo "$output" | grep -E "InternalBattery")

# No battery (desktop Mac) — just report AC power status
if [ -z "$battery_line" ]; then
  echo "macos_power ac_power=${ac_power}i"
  exit 0
fi

# Extract battery percentage
percent=$(echo "$battery_line" | grep -oE '[0-9]+%' | tr -d '%')

# Extract charge state: charging, discharging, charged, finishing charge
if echo "$battery_line" | grep -qi "charging"; then
  if echo "$battery_line" | grep -qi "not charging"; then
    charging=0
  else
    charging=1
  fi
else
  charging=0
fi

if echo "$battery_line" | grep -qi "charged"; then
  charged=1
else
  charged=0
fi

# Extract time remaining (minutes), if present
time_remaining=""
remaining_match=$(echo "$battery_line" | grep -oE '[0-9]+:[0-9]+')
if [ -n "$remaining_match" ]; then
  hours=$(echo "$remaining_match" | cut -d: -f1)
  mins=$(echo "$remaining_match" | cut -d: -f2)
  time_remaining=$(( hours * 60 + mins ))
fi

# Build line protocol
fields="ac_power=${ac_power}i,battery_percent=${percent}"
fields="${fields},charging=${charging}i,charged=${charged}i"
if [ -n "$time_remaining" ]; then
  fields="${fields},time_remaining_min=${time_remaining}i"
fi

echo "macos_power ${fields}"
