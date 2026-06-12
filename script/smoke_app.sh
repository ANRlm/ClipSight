#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/ClipSight.app"

usage() {
  cat >&2 <<'USAGE'
usage: script/smoke_app.sh [--app path/to/ClipSight.app]

Runs a manual macOS UI smoke test against a built ClipSight.app. This script
requires Automation permission for the invoking terminal so System Events can
inspect and click app UI elements.
USAGE
}

fail() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

[[ -d "$APP_BUNDLE" ]] || fail "app bundle not found: $APP_BUNDLE"
[[ -x "$APP_BUNDLE/Contents/MacOS/ClipSight" ]] || fail "ClipSight executable missing in $APP_BUNDLE"

if ! /usr/bin/osascript -e 'tell application "System Events" to get name of application processes' >/dev/null 2>&1; then
  fail "System Events automation is not available. Grant Automation permission to this terminal and rerun."
fi

/usr/bin/pkill -x ClipSight >/dev/null 2>&1 || true
/usr/bin/open -n "$APP_BUNDLE"
/bin/sleep 1.5

/usr/bin/osascript <<'APPLESCRIPT'
on failSmoke(message)
  error "Smoke test failed: " & message
end failSmoke

on findClipSightStatusItem()
  tell application "System Events"
    tell process "ClipSight"
      repeat with menuBarIndex from 1 to count of menu bars
        repeat with itemIndex from 1 to count of menu bar items of menu bar menuBarIndex
          set itemName to ""
          set itemDescription to ""
          try
            set itemName to name of menu bar item itemIndex of menu bar menuBarIndex
          end try
          try
            set itemDescription to description of menu bar item itemIndex of menu bar menuBarIndex
          end try
          if itemName contains "ClipSight" or itemDescription contains "ClipSight" then
            return {menuBarIndex, itemIndex}
          end if
        end repeat
      end repeat
    end tell
  end tell

  failSmoke("could not find ClipSight status item")
end findClipSightStatusItem

on clickStatusItem()
  set itemLocation to findClipSightStatusItem()
  set menuBarIndex to item 1 of itemLocation
  set itemIndex to item 2 of itemLocation
  tell application "System Events" to tell process "ClipSight"
    click menu bar item itemIndex of menu bar menuBarIndex
  end tell
end clickStatusItem

on clickSettingsItem()
  tell application "System Events" to tell process "ClipSight"
    set itemLocation to my findClipSightStatusItem()
    set menuBarIndex to item 1 of itemLocation
    set itemIndex to item 2 of itemLocation
    tell menu 1 of menu bar item itemIndex of menu bar menuBarIndex
      repeat with menuItemIndex from 1 to count of menu items
        set itemTitle to name of menu item menuItemIndex
        if itemTitle is "设置..." or itemTitle is "Settings..." then
          click menu item menuItemIndex
          return
        end if
      end repeat
    end tell
  end tell

  failSmoke("could not find Settings menu item")
end clickSettingsItem

on waitForSettingsWindow()
  tell application "System Events" to tell process "ClipSight"
    repeat with attempt from 1 to 30
      if (count of windows) > 0 then
        return
      end if
      delay 0.1
    end repeat
  end tell

  failSmoke("settings window did not appear")
end waitForSettingsWindow

clickStatusItem()
delay 0.2
clickSettingsItem()
waitForSettingsWindow()

tell application "System Events" to tell process "ClipSight"
  set focusedBefore to focused of window 1
end tell

clickStatusItem()
delay 0.2
tell application "System Events" to key code 53
delay 0.2
tell application "System Events" to tell process "ClipSight"
  set focusedAfterStatusMenu to focused of window 1
end tell

tell application "System Events" to tell process "ClipSight"
  try
    click menu bar item "ClipSight" of menu bar 1
    delay 0.2
    tell application "System Events" to key code 53
  end try
end tell
delay 0.2
tell application "System Events" to tell process "ClipSight"
  set focusedAfterAppMenu to focused of window 1
end tell

tell application "Finder" to set desktopBounds to bounds of window of desktop
set systemMenuX to (item 3 of desktopBounds) - 16
tell application "System Events" to click at {systemMenuX, 12}
delay 0.2
tell application "System Events" to key code 53
delay 0.2
tell application "System Events" to tell process "ClipSight"
  set focusedAfterSystemArea to focused of window 1
  click button 1 of window 1
end tell
delay 0.5
tell application "System Events" to tell process "ClipSight"
  set frontmostAfterClose to frontmost
  set backgroundOnlyAfterClose to background only
end tell

if focusedBefore is not true then failSmoke("settings window was not focused after opening")
if focusedAfterStatusMenu is not true then failSmoke("settings window lost focus after status menu interaction")
if focusedAfterAppMenu is not true then failSmoke("settings window lost focus after app menu interaction")
if focusedAfterSystemArea is not true then failSmoke("settings window lost focus after system menu area interaction")
if frontmostAfterClose is not false then failSmoke("app remained frontmost after closing settings")
if backgroundOnlyAfterClose is not true then failSmoke("app did not return to background-only mode after closing settings")

return "ClipSight smoke test passed"
APPLESCRIPT
