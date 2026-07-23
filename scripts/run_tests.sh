#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=26.5}"
RESULT_BUNDLE="${RESULT_BUNDLE:-build/TestResults.xcresult}"
INCLUDE_UI_TESTS="${INCLUDE_UI_TESTS:-1}"

mkdir -p build
rm -rf "$RESULT_BUNDLE"

TEST_ARGS=()
if [[ "$INCLUDE_UI_TESTS" == "0" ]]; then
  TEST_ARGS+=(
    -only-testing:TrailhoundTests
  )
fi

set +e
if ((${#TEST_ARGS[@]})); then
  xcodebuild test \
    -project Trailhound.xcodeproj \
    -scheme Trailhound \
    -destination "$DESTINATION" \
    -resultBundlePath "$RESULT_BUNDLE" \
    -parallel-testing-enabled NO \
    "${TEST_ARGS[@]}"
else
  xcodebuild test \
    -project Trailhound.xcodeproj \
    -scheme Trailhound \
    -destination "$DESTINATION" \
    -resultBundlePath "$RESULT_BUNDLE" \
    -parallel-testing-enabled NO
fi
STATUS=$?
set -e

if [[ "$STATUS" -ne 0 ]]; then
  echo "xcodebuild test failed with status $STATUS"
  echo "Result bundle: $RESULT_BUNDLE"
  exit "$STATUS"
fi

echo "All tests passed."
