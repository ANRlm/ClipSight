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
  SELECTED_DEVELOPER_DIR="$(/usr/bin/xcode-select -p 2>/dev/null || true)"
  XCODE_DEVELOPER_DIRS=(
    "${DEVELOPER_DIR:-}"
    "$SELECTED_DEVELOPER_DIR"
    "/Applications/Xcode.app/Contents/Developer"
    "/Applications/Xcode-beta.app/Contents/Developer"
  )
  for XCODE_DEVELOPER_DIR in "${XCODE_DEVELOPER_DIRS[@]}"; do
    [[ -n "$XCODE_DEVELOPER_DIR" ]] || continue
    XCODE_SWIFT="$XCODE_DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
    XCODE_SDK="$XCODE_DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    XCODE_XCTEST_MODULES="$XCODE_DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/usr/lib"
    XCODE_XCTEST_FRAMEWORKS="$XCODE_DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/Library/Frameworks"
    XCODE_XCTEST_AGENT="$XCODE_DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/Library/Xcode/Agents/xctest"
    if [[ ! -x "$XCODE_SWIFT" || ! -d "$XCODE_SDK" ]]; then
      continue
    fi

    SWIFT_BIN="$XCODE_SWIFT"
    export DEVELOPER_DIR="$XCODE_DEVELOPER_DIR"
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
    break
  done

  if [[ -z "${SWIFT_BIN:-}" ]]; then
    SWIFT_BIN="swift"
  fi
fi

cd "$ROOT_DIR"

run_swift_test() {
  local command=("$SWIFT_BIN" test)

  if [[ "${1:-}" == "--with-xctest-feature-flags" ]]; then
    command+=(--enable-xctest --disable-swift-testing)
    shift
  fi

  if [[ ${#XCTest_FLAGS[@]} -gt 0 ]]; then
    command+=("${XCTest_FLAGS[@]}")
  fi

  if [[ ${#ARGS[@]} -gt 0 ]]; then
    command+=("${ARGS[@]}")
  fi

  "${command[@]}"
}

set +e
TEST_OUTPUT="$(run_swift_test --with-xctest-feature-flags 2>&1)"
TEST_STATUS=$?
if [[ $TEST_STATUS -ne 0 &&
      ( "$TEST_OUTPUT" == *"Unknown option '--enable-xctest'"* ||
        "$TEST_OUTPUT" == *"Unknown option '--disable-swift-testing'"* ) ]]; then
  TEST_OUTPUT="$(run_swift_test 2>&1)"
  TEST_STATUS=$?
fi
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

TEST_BUNDLE=""
TEST_BUNDLE_NAMES=(ClipSightCoreTests.xctest ClipSightPackageTests.xctest)
for TEST_BUNDLE_NAME in "${TEST_BUNDLE_NAMES[@]}"; do
  for TEST_BUNDLE_CANDIDATE in \
    "$SCRATCH_PATH/out/Products/Debug/$TEST_BUNDLE_NAME" \
    "$SCRATCH_PATH/debug/$TEST_BUNDLE_NAME"
  do
    if [[ -d "$TEST_BUNDLE_CANDIDATE" ]]; then
      TEST_BUNDLE="$TEST_BUNDLE_CANDIDATE"
      break 2
    fi
  done
done
if [[ -z "$TEST_BUNDLE" ]]; then
  TEST_BUNDLE="$(find "$SCRATCH_PATH" \( -name 'ClipSightCoreTests.xctest' -o -name 'ClipSightPackageTests.xctest' \) -type d | head -n 1)"
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

if [[ ${#XCTEST_ARGS[@]} -gt 0 ]]; then
  exec "$XCODE_XCTEST_AGENT" "${XCTEST_ARGS[@]}" "$TEST_BUNDLE"
fi

exec "$XCODE_XCTEST_AGENT" "$TEST_BUNDLE"
