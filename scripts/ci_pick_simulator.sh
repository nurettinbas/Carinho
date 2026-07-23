#!/usr/bin/env bash
# Prints a xcodebuild -destination value for an available iPhone simulator.
set -euo pipefail

preferred_names=(
  "iPhone 16"
  "iPhone 16 Pro"
  "iPhone 17"
  "iPhone 15"
  "iPhone SE (3rd generation)"
)

for name in "${preferred_names[@]}"; do
  id=$(xcrun simctl list devices available | grep -F "${name} (" | head -1 | grep -oE '[A-F0-9-]{36}' || true)
  if [[ -n "$id" ]]; then
    echo "platform=iOS Simulator,id=${id}"
    exit 0
  fi
done

echo "No suitable iPhone simulator found." >&2
xcrun simctl list devices available >&2
exit 1
