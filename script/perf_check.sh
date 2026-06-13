#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/ClipSight.app"
ITERATIONS=3
MAX_RSS_DELTA_KB="${CLIPSIGHT_PERF_MAX_RSS_DELTA_KB:-120000}"

usage() {
  cat >&2 <<'USAGE'
usage: script/perf_check.sh [--app path/to/ClipSight.app] [--iterations n]

Runs a local UI performance smoke check. It launches ClipSight with the QA menu,
cycles settings, HUD, and placement editor flows, then reports RSS/CPU samples.
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
    --iterations)
      ITERATIONS="${2:-}"
      shift 2
      ;;
    --iterations=*)
      ITERATIONS="${1#--iterations=}"
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

[[ "$ITERATIONS" =~ ^[0-9]+$ ]] || fail "--iterations must be a positive integer"
[[ "$ITERATIONS" -gt 0 ]] || fail "--iterations must be greater than zero"
[[ -d "$APP_BUNDLE" ]] || fail "app bundle not found: $APP_BUNDLE"

APP_BINARY="$APP_BUNDLE/Contents/MacOS/ClipSight"
[[ -x "$APP_BINARY" ]] || fail "ClipSight executable missing in $APP_BUNDLE"

if ! /usr/bin/osascript -e 'tell application "System Events" to get name of application processes' >/dev/null 2>&1; then
  fail "System Events automation is not available. Grant Automation permission to this terminal and rerun."
fi

/usr/bin/pkill -x ClipSight >/dev/null 2>&1 || true
for _ in {1..30}; do
  if ! /usr/bin/pgrep -x ClipSight >/dev/null 2>&1; then
    break
  fi
  /bin/sleep 0.1
done

/usr/bin/open -n --env CLIPSIGHT_ENABLE_QA_MENU=1 "$APP_BUNDLE"

cleanup() {
  /usr/bin/pkill -x ClipSight >/dev/null 2>&1 || true
}
trap cleanup EXIT

APP_PID=""
for _ in {1..30}; do
  APP_PID="$(/usr/bin/pgrep -nx ClipSight || true)"
  if [[ -n "$APP_PID" ]] && /bin/ps -p "$APP_PID" >/dev/null 2>&1; then
    break
  fi
  /bin/sleep 0.1
done

if [[ -z "$APP_PID" ]] || ! /bin/ps -p "$APP_PID" >/dev/null 2>&1; then
  fail "ClipSight did not stay running"
fi

sample_metrics() {
  local label="$1"
  local values
  values="$(/bin/ps -o rss= -o %cpu= -p "$APP_PID" | /usr/bin/awk 'NF >= 2 {print $1 " " $2}')"
  [[ -n "$values" ]] || fail "could not sample process metrics"
  local rss cpu
  rss="$(/usr/bin/awk '{print $1}' <<<"$values")"
  cpu="$(/usr/bin/awk '{print $2}' <<<"$values")"
  printf '%s rss_kb=%s cpu_percent=%s\n' "$label" "$rss" "$cpu"
}

/bin/sleep 1.2
BASELINE_LINE="$(sample_metrics baseline)"
echo "$BASELINE_LINE"
BASELINE_RSS="$(/usr/bin/awk -F'[ =]' '{print $3}' <<<"$BASELINE_LINE")"

CLIPSIGHT_PERF_ITERATIONS="$ITERATIONS" /usr/bin/osascript <<'APPLESCRIPT'
on failPerf(message)
  error "Perf check failed: " & message
end failPerf

set openSettingsIteration to 0
set showSuccessHUD to {"显示成功 HUD", "Show Success HUD"}
set showNoTextHUD to {"显示无文本 HUD", "Show No Text HUD"}
set showFailureHUD to {"显示失败 HUD", "Show Failure HUD"}
set adjustHUDPosition to {"调整 HUD 位置", "Adjust HUD Position"}

on findClipSightStatusItem()
  tell application "System Events"
    tell process "ClipSight"
      repeat with menuBarIndex from 1 to count of menu bars
        repeat with itemIndex from 1 to count of menu bar items of menu bar menuBarIndex
          set itemDescription to ""
          try
            set itemDescription to description of menu bar item itemIndex of menu bar menuBarIndex
          end try
          if itemDescription contains "ClipSight" then
            return {menuBarIndex, itemIndex}
          end if
        end repeat
      end repeat

      repeat with menuBarIndex from 1 to count of menu bars
        repeat with itemIndex from 1 to count of menu bar items of menu bar menuBarIndex
          set itemName to ""
          try
            set itemName to name of menu bar item itemIndex of menu bar menuBarIndex
          end try
          if itemName contains "ClipSight" then
            return {menuBarIndex, itemIndex}
          end if
        end repeat
      end repeat
    end tell
  end tell

  failPerf("could not find ClipSight status item")
end findClipSightStatusItem

on clickStatusItem()
  set itemLocation to findClipSightStatusItem()
  set menuBarIndex to item 1 of itemLocation
  set itemIndex to item 2 of itemLocation
  tell application "System Events" to tell process "ClipSight"
    click menu bar item itemIndex of menu bar menuBarIndex
  end tell
end clickStatusItem

on clickTopMenuItem(targetTitles)
  clickStatusItem()
  delay 0.12
  set itemLocation to findClipSightStatusItem()
  set menuBarIndex to item 1 of itemLocation
  set itemIndex to item 2 of itemLocation
  tell application "System Events" to tell process "ClipSight"
    tell menu 1 of menu bar item itemIndex of menu bar menuBarIndex
      repeat with menuItemIndex from 1 to count of menu items
        set itemTitle to name of menu item menuItemIndex
        if targetTitles contains itemTitle then
          click menu item menuItemIndex
          return
        end if
      end repeat
    end tell
  end tell

  failPerf("could not find top-level menu item")
end clickTopMenuItem

on clickDevelopmentMenuItem(targetTitles)
  clickStatusItem()
  delay 0.12
  set itemLocation to findClipSightStatusItem()
  set menuBarIndex to item 1 of itemLocation
  set itemIndex to item 2 of itemLocation
  tell application "System Events" to tell process "ClipSight"
    tell menu 1 of menu bar item itemIndex of menu bar menuBarIndex
      repeat with menuItemIndex from 1 to count of menu items
        set itemTitle to name of menu item menuItemIndex
        if itemTitle is "开发验证" or itemTitle is "Development QA" then
          tell menu 1 of menu item menuItemIndex
            repeat with qaItemIndex from 1 to count of menu items
              set qaTitle to name of menu item qaItemIndex
              if targetTitles contains qaTitle then
                click menu item qaItemIndex
                return
              end if
            end repeat
          end tell
        end if
      end repeat
    end tell
  end tell

  failPerf("could not find development QA menu item")
end clickDevelopmentMenuItem

on waitForSettingsWindow()
  tell application "System Events" to tell process "ClipSight"
    repeat with attempt from 1 to 30
      if (count of windows) > 0 then
        return
      end if
      delay 0.1
    end repeat
  end tell

  failPerf("settings window did not appear")
end waitForSettingsWindow

set iterations to (system attribute "CLIPSIGHT_PERF_ITERATIONS") as integer
repeat with openSettingsIteration from 1 to iterations
  clickTopMenuItem({"设置...", "Settings..."})
  waitForSettingsWindow()
  tell application "System Events" to tell process "ClipSight"
    click button 1 of window 1
  end tell
  delay 0.2
end repeat

repeat with hudIteration from 1 to iterations
  clickDevelopmentMenuItem(showSuccessHUD)
  delay 0.25
  clickDevelopmentMenuItem(showNoTextHUD)
  delay 0.25
  clickDevelopmentMenuItem(showFailureHUD)
  delay 0.45
end repeat

repeat with placementIteration from 1 to iterations
  clickDevelopmentMenuItem(adjustHUDPosition)
  delay 0.25
  tell application "System Events" to key code 53
  delay 0.25
end repeat
APPLESCRIPT

/bin/sleep 1.0
FINAL_LINE="$(sample_metrics final)"
echo "$FINAL_LINE"
FINAL_RSS="$(/usr/bin/awk -F'[ =]' '{print $3}' <<<"$FINAL_LINE")"
RSS_DELTA=$((FINAL_RSS - BASELINE_RSS))
echo "RSS delta kb=$RSS_DELTA"

if [[ "$RSS_DELTA" -gt "$MAX_RSS_DELTA_KB" ]]; then
  fail "RSS delta $RSS_DELTA KB exceeds limit $MAX_RSS_DELTA_KB KB"
fi

echo "ClipSight performance check passed"
