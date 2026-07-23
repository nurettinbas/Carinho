#!/usr/bin/env bash
# Prints a xcodebuild -destination value for an available iPhone simulator.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

preferred=("iPhone 17" "iPhone 16" "iPhone 16 Pro" "iPhone 15" "iPhone SE (3rd generation)")
uuid_re='[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}'

pick_from_simctl() {
  local devices
  devices="$(xcrun simctl list devices available)"
  local name id
  for name in "${preferred[@]}"; do
    id="$(printf '%s\n' "$devices" | grep -F "    ${name} (" | head -1 | grep -oE "$uuid_re" || true)"
    if [[ -n "$id" ]]; then
      echo "platform=iOS Simulator,id=${id}"
      return 0
    fi
  done
  return 1
}

pick_from_xcodebuild() {
  local destinations_file line pick_line id
  destinations_file="$(mktemp)"
  xcodebuild -showdestinations -project Trailhound.xcodeproj -scheme Trailhound 2>/dev/null \
    | grep -E "platform: ?iOS Simulator" \
    | grep -vi placeholder \
    | grep -E "name: ?iPhone" > "$destinations_file" || true

  if [[ ! -s "$destinations_file" ]]; then
    rm -f "$destinations_file"
    return 1
  fi

  pick_line=""
  local name
  while IFS= read -r line; do
    for name in "${preferred[@]}"; do
      if [[ "$line" == *"name:${name}"* ]] || [[ "$line" == *"name: ${name}"* ]]; then
        pick_line="$line"
        break 2
      fi
    done
  done < "$destinations_file"

  if [[ -z "$pick_line" ]]; then
    pick_line="$(head -1 "$destinations_file")"
  fi
  rm -f "$destinations_file"

  id="$(echo "$pick_line" | grep -oE "id:${uuid_re}" | head -1 | cut -d: -f2)"
  if [[ -z "$id" ]]; then
    return 1
  fi

  echo "platform=iOS Simulator,id=${id}"
}

pick_fallback_name_os() {
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    # GitHub macos-26 ships iPhone 17 + iOS 26.x with Xcode 26.
    echo "platform=iOS Simulator,name=iPhone 17,OS=26.5"
  else
    echo "platform=iOS Simulator,name=iPhone 16,OS=18.5"
  fi
}

if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  if pick_from_xcodebuild; then exit 0; fi
  if pick_from_simctl; then exit 0; fi
  pick_fallback_name_os
  exit 0
fi

if pick_from_simctl; then exit 0; fi
if pick_from_xcodebuild; then exit 0; fi
pick_fallback_name_os
