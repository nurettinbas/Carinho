#!/usr/bin/env bash
# Prints a xcodebuild -destination value using destinations Xcode can actually use.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

preferred=("iPhone 16" "iPhone 16 Pro" "iPhone 17" "iPhone 15" "iPhone SE (3rd generation)")

destinations_file="$(mktemp)"
xcodebuild -showdestinations -project Trailhound.xcodeproj -scheme Trailhound 2>/dev/null \
  | grep "platform:iOS Simulator" \
  | grep -v "placeholder" \
  | grep "name:iPhone" > "$destinations_file" || true

if [[ ! -s "$destinations_file" ]]; then
  echo "No iPhone simulator destinations reported by xcodebuild." >&2
  xcodebuild -showdestinations -project Trailhound.xcodeproj -scheme Trailhound >&2 || true
  rm -f "$destinations_file"
  exit 1
fi

pick_line=""
while IFS= read -r line; do
  for name in "${preferred[@]}"; do
    if [[ "$line" == *"name:${name}"* ]]; then
      pick_line="$line"
      break 2
    fi
  done
done < "$destinations_file"

if [[ -z "$pick_line" ]]; then
  pick_line="$(head -1 "$destinations_file")"
fi
rm -f "$destinations_file"

id=$(echo "$pick_line" | grep -oE 'id:[A-F0-9-]+' | head -1 | cut -d: -f2)
if [[ -z "$id" ]]; then
  echo "Could not parse simulator id from: $pick_line" >&2
  exit 1
fi

echo "platform=iOS Simulator,id=${id}"
