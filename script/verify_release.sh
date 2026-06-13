#!/usr/bin/env bash
set -euo pipefail

MODE="local"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/ClipSight.app"

usage() {
  cat >&2 <<'USAGE'
usage: script/verify_release.sh [--mode local] [--app path/to/ClipSight.app]

Validates the local ad-hoc ClipSight.app bundle. Gatekeeper rejection is allowed
for this release model.
USAGE
}

fail() {
  echo "error: $*" >&2
  exit 1
}

read_plist() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --mode=*)
      MODE="${1#--mode=}"
      shift
      ;;
    --app)
      APP_BUNDLE="${2:-}"
      shift 2
      ;;
    --app=*)
      APP_BUNDLE="${1#--app=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      fail "unknown argument: $1"
      ;;
  esac
done

if [[ "$MODE" != "local" ]]; then
  fail "mode must be local"
fi

[[ -d "$APP_BUNDLE" ]] || fail "app bundle not found: $APP_BUNDLE"

INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
[[ -f "$INFO_PLIST" ]] || fail "Info.plist is missing"

BUNDLE_NAME="$(read_plist CFBundleName)"
EXECUTABLE_NAME="$(read_plist CFBundleExecutable)"
BUNDLE_ID="$(read_plist CFBundleIdentifier)"
PACKAGE_TYPE="$(read_plist CFBundlePackageType)"
SHORT_VERSION="$(read_plist CFBundleShortVersionString)"
BUILD_NUMBER="$(read_plist CFBundleVersion)"
MIN_SYSTEM_VERSION="$(read_plist LSMinimumSystemVersion)"

[[ "$BUNDLE_NAME" == "ClipSight" ]] || fail "unexpected CFBundleName: $BUNDLE_NAME"
[[ "$EXECUTABLE_NAME" == "ClipSight" ]] || fail "unexpected CFBundleExecutable: $EXECUTABLE_NAME"
[[ "$BUNDLE_ID" == "com.local.ClipSight" ]] || fail "unexpected CFBundleIdentifier: $BUNDLE_ID"
[[ "$PACKAGE_TYPE" == "APPL" ]] || fail "unexpected CFBundlePackageType: $PACKAGE_TYPE"
[[ -n "$SHORT_VERSION" ]] || fail "CFBundleShortVersionString is empty"
[[ -n "$BUILD_NUMBER" ]] || fail "CFBundleVersion is empty"
[[ "$MIN_SYSTEM_VERSION" == "13.0" ]] || fail "unexpected LSMinimumSystemVersion: $MIN_SYSTEM_VERSION"

APP_BINARY="$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
APP_ICON="$APP_BUNDLE/Contents/Resources/AppIcon.icns"
[[ -x "$APP_BINARY" ]] || fail "app executable is missing or not executable: $APP_BINARY"
[[ -f "$APP_ICON" ]] || fail "app icon is missing: $APP_ICON"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if command -v spctl >/dev/null 2>&1; then
  set +e
  SPCTL_OUTPUT="$(spctl -a -vv --type execute "$APP_BUNDLE" 2>&1)"
  SPCTL_STATUS=$?
  set -e

  if [[ $SPCTL_STATUS -ne 0 ]]; then
    echo "Gatekeeper rejected local ad-hoc build as expected/allowed:" >&2
    printf '%s\n' "$SPCTL_OUTPUT" >&2
  else
    printf '%s\n' "$SPCTL_OUTPUT"
  fi
else
  echo "spctl not found; skipped Gatekeeper assessment." >&2
fi

echo "Verified local release: $APP_BUNDLE"
