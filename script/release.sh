#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=""
BUILD_NUMBER=""
PUSH="false"

usage() {
  cat >&2 <<'USAGE'
usage: script/release.sh --version x.y.z [--build n] [--push]

Creates a guarded ClipSight local ad-hoc release from a clean main checkout.

Options:
  --version       Required. Marketing version without leading v, for example 0.5.0.
  --build         Optional. CFBundleVersion. Defaults to git commit count.
  --push          Push main/tag and create a GitHub release. Without this flag,
                  the script builds, verifies, and creates only a local tag.
USAGE
}

fail() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --version=*)
      VERSION="${1#--version=}"
      shift
      ;;
    --build)
      BUILD_NUMBER="${2:-}"
      shift 2
      ;;
    --build=*)
      BUILD_NUMBER="${1#--build=}"
      shift
      ;;
    --push)
      PUSH="true"
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

cd "$ROOT_DIR"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "--version must match x.y.z"
[[ "$(git branch --show-current)" == "main" ]] || fail "release must be run from main"
git diff --quiet || fail "working tree has unstaged changes"
git diff --cached --quiet || fail "index has staged changes"
git fetch --tags origin >/dev/null 2>&1 || true

TAG="v$VERSION"
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  fail "local tag already exists: $TAG"
fi
if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  fail "remote tag already exists: $TAG"
fi

if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$(git rev-list --count HEAD)"
fi

./script/test.sh

MARKETING_VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" ./script/package_app.sh --distribution local
script/verify_release.sh --mode local
ASSET="dist/ClipSight-$VERSION-local.zip"
DMG_ASSET="dist/ClipSight-$VERSION-local.dmg"
[[ -f "$ASSET" ]] || fail "release asset missing: $ASSET"
[[ -f "$DMG_ASSET" ]] || fail "release asset missing: $DMG_ASSET"

git tag -a "$TAG" -m "ClipSight $VERSION"

if [[ "$PUSH" != "true" ]]; then
  echo "Created local tag $TAG and verified $ASSET."
  echo "Re-run with --push to push the tag and create a GitHub release."
  exit 0
fi

NOTES_FILE="$(mktemp)"
cat > "$NOTES_FILE" <<EOF
ClipSight $VERSION

This release uses local/ad-hoc signing. macOS may block it on first launch.
Download the DMG for the normal drag-to-Applications install flow, or the zip
as a fallback. If macOS blocks the app, open it from Finder with Control-click
or right-click, then choose Open.
EOF

git push origin main
git push origin "$TAG"
gh release create "$TAG" "$ASSET" "$DMG_ASSET" \
  --repo ANRlm/ClipSight \
  --title "ClipSight $VERSION" \
  --notes-file "$NOTES_FILE"
