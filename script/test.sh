#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${SWIFT_BIN:-}" ]]; then
  XCODE_SWIFT="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
  XCODE_SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
  XCODE_TESTING_FRAMEWORKS="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"
  if [[ -x "$XCODE_SWIFT" && -d "$XCODE_SDK" && -d "$XCODE_TESTING_FRAMEWORKS" ]]; then
    SWIFT_BIN="$XCODE_SWIFT"
    export SDKROOT="${SDKROOT:-$XCODE_SDK}"
    export DYLD_FRAMEWORK_PATH="${DYLD_FRAMEWORK_PATH:-$XCODE_TESTING_FRAMEWORKS}"
    TESTING_FRAMEWORKS="$XCODE_TESTING_FRAMEWORKS"
  else
    SWIFT_BIN="swift"
    TESTING_FRAMEWORKS=""
  fi
else
  TESTING_FRAMEWORKS="${TESTING_FRAMEWORKS:-}"
fi

cd "$ROOT_DIR"

if [[ -n "$TESTING_FRAMEWORKS" ]]; then
  exec "$SWIFT_BIN" test \
    --enable-swift-testing \
    -Xswiftc -F \
    -Xswiftc "$TESTING_FRAMEWORKS" \
    "$@"
fi

exec "$SWIFT_BIN" test --enable-swift-testing "$@"
