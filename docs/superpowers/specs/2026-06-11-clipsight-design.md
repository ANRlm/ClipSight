# ClipSight Design Spec

## Goal

Build ClipSight, a lightweight native macOS menu bar app for local OCR. Users trigger a system screen selection flow from the menu bar or a user-configured global shortcut. After selection, the app recognizes Chinese and English text locally with Apple Vision, copies the result to the clipboard, shows a concise on-screen HUD, and removes temporary screenshot files.

ClipSight must not provide a preview window, OCR history, custom screenshot overlay, network OCR, or language switching.

## Platform And Packaging

- Target platform: macOS 13 Ventura and later.
- Language and UI: Swift, SwiftUI, and AppKit where required.
- Project shape: Swift Package Manager project that can build a macOS executable.
- App delivery: `script/package_app.sh` packages the SwiftPM executable into `ClipSight.app` with an `Info.plist` suitable for double-click launch and login item registration.
- App icon: generated locally by `script/generate_app_icon.swift` during packaging.
- Signing: local packages use ad-hoc signing by default with a stable bundle identifier requirement; `CODESIGN_IDENTITY` can override this for certificate signing.
- Network use: none.

## User Experience

ClipSight runs as a menu bar-only app.

The menu bar menu contains:

- `截图识别`: starts the OCR capture flow.
- Current shortcut status: displays the configured shortcut or `未设置`.
- `设置...`: opens the settings window.
- `退出`: quits the app.

There is no default global shortcut. On first launch, the shortcut state is unset. Users can still run OCR from the menu bar until they configure a shortcut.

When OCR succeeds, ClipSight writes recognized text to the general pasteboard, stores a menu status such as `已复制 12 行文本`, and shows a short screen HUD such as `已复制到剪贴板`. If no text is detected, it shows a clear no-text HUD. If the user cancels the system screenshot selection, the app cleans up and exits the flow without treating it as an error.

## Settings Window

The settings window is simple, native, and visually restrained. It uses SwiftUI with standard macOS controls and spacing.

Sections:

- Header: app name `ClipSight` and a short local OCR description.
- Shortcut: current shortcut display, `录制快捷键`, and `清除`.
- Launch at login: native toggle backed by `SMAppService.mainApp`.
- Permissions:
  - Screen recording permission status and a button to open the relevant System Settings pane.
  - Accessibility permission status and a button to open the relevant System Settings pane.
- Local processing note: states that OCR runs fully on the Mac with Apple Vision.

The app does not include OCR language selection. Recognition defaults to Simplified Chinese and English.

## Architecture

### `ClipSightApp`

SwiftUI app entry point. Owns app-level state, declares `MenuBarExtra`, keeps the app menu-bar only, and wires actions to the coordinator and settings window presenter.

### `AppState`

Observable state container for:

- Current shortcut.
- Permission statuses.
- Launch-at-login state.
- Current OCR progress state.
- Last user-facing status or error summary.

### `CaptureOCRCoordinator`

Coordinates the end-to-end flow:

1. Check relevant permissions.
2. Ask `ScreenCaptureService` for a selected screenshot.
3. Pass the image file to `OCRService`.
4. Write recognized text through `ClipboardService`.
5. Show a concise HUD through `StatusHUDPresenter`.
6. Clean temporary files in all success, cancel, and error paths.

### `HotKeyManager`

Registers and unregisters one global shortcut using Carbon `RegisterEventHotKey`.

Responsibilities:

- Persist the user-configured shortcut.
- Detect missing shortcut state.
- Register the shortcut when set.
- Re-register after shortcut changes.
- Report registration failures, including likely conflicts.

There is no default shortcut.

### `ShortcutRecorder`

Small AppKit-backed SwiftUI control that captures key-down events while recording. It converts modifier flags and key codes into a persistable `HotKey` value and a display string.

### `ScreenCaptureService`

Uses macOS system screenshot selection:

```text
/usr/sbin/screencapture -i <temporary-file>
```

The service returns:

- A temporary image file URL when the user completes selection.
- A cancellation result when the user presses Escape or closes the screenshot flow.
- A failure result for command execution errors or unreadable output.

The service does not implement a custom overlay.

### `OCRService`

Uses Apple Vision `VNRecognizeTextRequest` locally.

Configuration:

- Recognition level: accurate.
- Recognition languages: `zh-Hans`, `en-US`.
- Language correction: enabled.

The service loads the captured image, performs recognition, sorts observations in a stable reading order, joins recognized lines with newlines, and returns plain text.

### `ClipboardService`

Writes non-empty OCR text to `NSPasteboard.general` as a string.

### `PermissionService`

Reports permission state and opens System Settings panes.

Permission checks:

- Screen recording: `CGPreflightScreenCaptureAccess`.
- Accessibility: `AXIsProcessTrusted`.

Opening settings:

- Screen recording: Privacy & Security screen recording pane URL.
- Accessibility: Privacy & Security accessibility pane URL.

The app explains missing permissions in settings and shows actionable errors when capture cannot proceed.

Screen recording is required for OCR. Accessibility is shown as optional because the current global shortcut implementation uses Carbon `RegisterEventHotKey` and does not depend on accessibility trust.

On first launch, if screen recording permission is missing, ClipSight opens its own settings window once to explain the required permission. This first-launch prompt is stored in `UserDefaults` and does not repeatedly interrupt subsequent launches. OCR attempts made without screen recording permission still open the relevant macOS System Settings pane.

When the app becomes active again, ClipSight refreshes screen recording, accessibility, and launch-at-login status so returning from System Settings updates the settings UI without requiring a manual refresh.

### `LaunchAtLoginService`

Wraps `SMAppService.mainApp` for reading and toggling launch-at-login state.

### `TemporaryFileCleaner`

Creates screenshot paths under the system temporary directory and deletes them after the flow. Cleanup runs after success, cancellation, OCR failure, and clipboard failure.

### `StatusHUDPresenter`

Uses a non-activating `NSPanel` with SwiftUI content to show short success and failure status near the top-center of the screen. HUD messages do not include OCR content. The app does not request `UserNotifications` permission.

## Data Model

### `HotKey`

Stores:

- Carbon key code.
- Modifier flags.
- Display string.

Persistence uses `UserDefaults`.

### `PermissionStatus`

Stores:

- Status kind: authorized or missing.
- User-facing label.
- Optional action to open settings.

## Error Handling

Errors are classified into user-facing cases:

- Shortcut registration failed.
- Screen recording permission missing.
- Screenshot cancelled.
- Screenshot failed.
- OCR failed.
- No text recognized.
- Clipboard write failed.
- Temporary file cleanup failed.

Screenshot cancellation is not treated as a failure. Cleanup failure is logged but does not block successful OCR copy.

## Testing And Verification

Build verification:

- `swift build`
- `./script/test.sh`
- package script execution for `.app` creation
- `codesign --verify --deep --strict dist/ClipSight.app`
- Optional OCR integration verification with `CLIPSIGHT_RUN_OCR_INTEGRATION=1 ./script/test.sh --filter OCRServiceIntegrationTests`

Runtime verification:

- Launch app bundle.
- Confirm menu bar item appears.
- Confirm settings window opens automatically once on first launch when screen recording permission is missing.
- Configure and clear a shortcut.
- Confirm missing screen recording permission is shown in settings and opens System Settings only from an explicit action or OCR attempt.
- Confirm permission state refreshes after returning from System Settings.
- Trigger OCR from menu bar.
- Trigger OCR from configured shortcut.
- Cancel screenshot selection and confirm no stale temp files remain.
- Capture a region with Chinese and English text and confirm recognized text lands in the clipboard.
- Confirm success and failure HUDs render clearly in light and dark mode.
- Toggle launch at login and confirm state changes.

Some runtime checks require user-controlled macOS permissions and cannot be fully automated in CI.

## README Requirements

The README must include:

- What ClipSight does.
- macOS version requirement.
- Build command.
- App bundle packaging command.
- How to run the app.
- No default shortcut; users configure their own in settings.
- Required permissions: screen recording.
- Optional status display for accessibility.
- OCR is fully local through Apple Vision and does not call network services.

## Out Of Scope

- OCR history.
- Preview or editing window.
- Custom screenshot UI.
- Network OCR.
- Language mode switching.
- Menu bar popovers with rich previews.
- iCloud sync or cross-device behavior.
