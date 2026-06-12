#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCTest_FLAGS=()
SCRATCH_PATH=".build"
FILTERS=()
ARGS=("$@")

for ((index = 0; index < ${#ARGS[@]}; index++)); do
  case "${ARGS[$index]}" in
    --scratch-path)
      index=$((index + 1))
      SCRATCH_PATH="${ARGS[$index]:-.build}"
      ;;
    --scratch-path=*)
      SCRATCH_PATH="${ARGS[$index]#--scratch-path=}"
      ;;
    --filter|-s|--specifier)
      index=$((index + 1))
      FILTERS+=("${ARGS[$index]:-}")
      ;;
    --filter=*|--specifier=*)
      FILTERS+=("${ARGS[$index]#*=}")
      ;;
  esac
done

if [[ -z "${SWIFT_BIN:-}" ]]; then
  XCODE_SWIFT="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
  XCODE_SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
  XCODE_XCTEST_MODULES="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib"
  XCODE_XCTEST_FRAMEWORKS="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"
  XCODE_XCTEST_AGENT="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Xcode/Agents/xctest"
  if [[ -x "$XCODE_SWIFT" && -d "$XCODE_SDK" ]]; then
    SWIFT_BIN="$XCODE_SWIFT"
    export SDKROOT="${SDKROOT:-$XCODE_SDK}"
    FILTERED_FRAMEWORKS="$ROOT_DIR/.build/xctest-frameworks"
    mkdir -p "$FILTERED_FRAMEWORKS"
    ln -sfn "$XCODE_XCTEST_FRAMEWORKS/XCTest.framework" "$FILTERED_FRAMEWORKS/XCTest.framework"
    ln -sfn "$XCODE_XCTEST_FRAMEWORKS/XCUIAutomation.framework" "$FILTERED_FRAMEWORKS/XCUIAutomation.framework"
    XCTest_FLAGS=(
      -Xswiftc -I
      -Xswiftc "$XCODE_XCTEST_MODULES"
      -Xswiftc -F
      -Xswiftc "$FILTERED_FRAMEWORKS"
      -Xlinker -F
      -Xlinker "$FILTERED_FRAMEWORKS"
      -Xlinker -L
      -Xlinker "$XCODE_XCTEST_MODULES"
      -Xlinker -framework
      -Xlinker XCTest
    )
  else
    SWIFT_BIN="swift"
  fi
fi

cd "$ROOT_DIR"

set +e
TEST_OUTPUT="$("$SWIFT_BIN" test --enable-xctest --disable-swift-testing "${XCTest_FLAGS[@]}" "$@" 2>&1)"
TEST_STATUS=$?
set -e

if [[ $TEST_STATUS -eq 0 ]]; then
  printf '%s\n' "$TEST_OUTPUT"
  exit 0
fi

if [[ "$TEST_OUTPUT" != *"XCTest not available"* && "$TEST_OUTPUT" != *"unable to load libxcrun"* ]]; then
  printf '%s\n' "$TEST_OUTPUT" >&2
  exit "$TEST_STATUS"
fi

if [[ ! -x "${XCODE_XCTEST_AGENT:-}" ]]; then
  printf '%s\n' "$TEST_OUTPUT" >&2
  exit "$TEST_STATUS"
fi

TEST_BUNDLE="$(find "$SCRATCH_PATH" -mindepth 3 -maxdepth 3 -name 'ClipSightPackageTests.xctest' -type d | head -n 1)"
if [[ -z "$TEST_BUNDLE" ]]; then
  TEST_BUNDLE="$(find "$SCRATCH_PATH" -name 'ClipSightPackageTests.xctest' -type d | head -n 1)"
fi
if [[ -z "$TEST_BUNDLE" ]]; then
  printf '%s\n' "$TEST_OUTPUT" >&2
  echo "error: built test bundle was not found under $SCRATCH_PATH" >&2
  exit "$TEST_STATUS"
fi

echo "swift test built the bundle but could not launch XCTest through xcrun; using Xcode xctest agent fallback." >&2

XCTEST_ARGS=()
if [[ ${#FILTERS[@]} -gt 0 ]]; then
  joined_filters="$(IFS=,; echo "${FILTERS[*]}")"
  XCTEST_ARGS=(-XCTest "$joined_filters")
fi

exec "$XCODE_XCTEST_AGENT" "${XCTEST_ARGS[@]}" "$TEST_BUNDLE"
