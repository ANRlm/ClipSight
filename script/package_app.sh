#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="release"
DISTRIBUTION="local"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--configuration)
      CONFIGURATION="${2:-}"
      shift 2
      ;;
    --distribution)
      DISTRIBUTION="${2:-}"
      shift 2
      ;;
    --distribution=*)
      DISTRIBUTION="${1#--distribution=}"
      shift
      ;;
    debug|release)
      CONFIGURATION="$1"
      shift
      ;;
    -h|--help)
      cat >&2 <<'USAGE'
usage: script/package_app.sh [--configuration debug|release] [--distribution local|developer-id|notarized]

Distributions:
  local         Build dist/ClipSight.app with ad-hoc signing and create
                dist/ClipSight-<version>-local.zip. This is the default.
  developer-id Build, sign with Developer ID, and create
                dist/ClipSight-<version>-developer-id.zip for manual notarization.
  notarized    Build, sign with Developer ID, submit to notarytool, staple,
                and create dist/ClipSight-<version>.zip.

Developer ID environment:
  CODESIGN_IDENTITY     Required. Developer ID Application signing identity.
  CLIPSIGHT_BUNDLE_ID   Required. Release bundle identifier.
  MARKETING_VERSION     Optional, defaults to 0.4.0.
  BUILD_NUMBER          Optional, defaults to 1.
  NOTARYTOOL_PROFILE    Required for --distribution notarized. Keychain profile
                        for xcrun notarytool.
USAGE
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ "$CONFIGURATION" != "debug" && "$CONFIGURATION" != "release" ]]; then
  echo "configuration must be debug or release" >&2
  exit 2
fi

if [[ "$DISTRIBUTION" != "local" && "$DISTRIBUTION" != "developer-id" && "$DISTRIBUTION" != "notarized" ]]; then
  echo "distribution must be local, developer-id, or notarized" >&2
  exit 2
fi

APP_NAME="ClipSight"
BUNDLE_ID="${CLIPSIGHT_BUNDLE_ID:-com.local.ClipSight}"
MARKETING_VERSION="${MARKETING_VERSION:-0.4.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MIN_SYSTEM_VERSION="13.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
ICON_FILE="$APP_RESOURCES/AppIcon.icns"
case "$DISTRIBUTION" in
  local)
    ZIP_FILE="$DIST_DIR/$APP_NAME-$MARKETING_VERSION-local.zip"
    ;;
  developer-id)
    ZIP_FILE="$DIST_DIR/$APP_NAME-$MARKETING_VERSION-developer-id.zip"
    ;;
  notarized)
    ZIP_FILE="$DIST_DIR/$APP_NAME-$MARKETING_VERSION.zip"
    ;;
esac

if [[ "$DISTRIBUTION" == "developer-id" || "$DISTRIBUTION" == "notarized" ]]; then
  if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
    echo "CODESIGN_IDENTITY is required for --distribution $DISTRIBUTION" >&2
    exit 2
  fi

  if [[ -z "${CLIPSIGHT_BUNDLE_ID:-}" ]]; then
    echo "CLIPSIGHT_BUNDLE_ID is required for --distribution $DISTRIBUTION" >&2
    exit 2
  fi
fi

if [[ "$DISTRIBUTION" == "notarized" ]]; then
  if [[ -z "${NOTARYTOOL_PROFILE:-}" ]]; then
    echo "NOTARYTOOL_PROFILE is required for --distribution notarized" >&2
    exit 2
  fi
fi

if [[ -z "${SWIFT_BIN:-}" ]]; then
  XCODE_SWIFT="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
  XCODE_SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
  if [[ -x "$XCODE_SWIFT" && -d "$XCODE_SDK" ]]; then
    SWIFT_BIN="$XCODE_SWIFT"
    export SDKROOT="${SDKROOT:-$XCODE_SDK}"
  else
    SWIFT_BIN="swift"
  fi
fi

cd "$ROOT_DIR"

"$SWIFT_BIN" build -c "$CONFIGURATION" --product "$APP_NAME"
BUILD_DIR="$("$SWIFT_BIN" build -c "$CONFIGURATION" --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"

rm -rf "$APP_BUNDLE"
rm -f "$ZIP_FILE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

"$SWIFT_BIN" "$ROOT_DIR/script/generate_app_icon.swift" "$ICONSET_DIR"
/usr/bin/iconutil --convert icns --output "$ICON_FILE" "$ICONSET_DIR"
rm -rf "$ICONSET_DIR"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon.icns</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$MARKETING_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  if [[ "$DISTRIBUTION" == "local" ]]; then
    codesign \
      --force \
      --deep \
      --sign - \
      --requirements "=designated => identifier \"$BUNDLE_ID\"" \
      "$APP_BUNDLE" >/dev/null
  else
    codesign \
      --force \
      --deep \
      --options runtime \
      --timestamp \
      --sign "$CODESIGN_IDENTITY" \
      "$APP_BUNDLE" >/dev/null
  fi

  codesign --verify --deep --strict "$APP_BUNDLE"
else
  echo "codesign is required to package ClipSight.app" >&2
  exit 2
fi

touch "$APP_BUNDLE"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

if command -v qlmanage >/dev/null 2>&1; then
  qlmanage -r cache >/dev/null 2>&1 || true
fi

if [[ "$DISTRIBUTION" == "local" || "$DISTRIBUTION" == "developer-id" ]]; then
  /usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_FILE"
fi

if [[ "$DISTRIBUTION" == "notarized" ]]; then
  /usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_FILE"
  /usr/bin/xcrun notarytool submit "$ZIP_FILE" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait
  /usr/bin/xcrun stapler staple "$APP_BUNDLE"
  /usr/bin/xcrun stapler validate "$APP_BUNDLE"
  rm -f "$ZIP_FILE"
  /usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_FILE"
fi

echo "$APP_BUNDLE"
echo "$ZIP_FILE"
