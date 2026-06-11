import AppKit
import ClipSightCore
import SwiftUI

@main
@MainActor
struct ClipSightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState

    private let hotKeyManager: HotKeyManager
    private let permissionService: PermissionService
    private let launchAtLoginService: LaunchAtLoginService
    private let coordinator: CaptureOCRCoordinator
    private let settingsWindowPresenter: SettingsWindowPresenter

    init() {
        let state = AppState()
        let permissionService = PermissionService()
        let launchAtLoginService = LaunchAtLoginService()
        let hotKeyManager = HotKeyManager()
        let settingsWindowPresenter = SettingsWindowPresenter()
        let coordinator = CaptureOCRCoordinator(
            appState: state,
            permissionService: permissionService,
            screenCaptureService: ScreenCaptureService(),
            ocrService: OCRService(),
            clipboardService: ClipboardService(),
            statusPresenter: StatusHUDPresenter(),
            temporaryFileCleaner: TemporaryFileCleaner()
        )

        _appState = StateObject(wrappedValue: state)
        self.permissionService = permissionService
        self.launchAtLoginService = launchAtLoginService
        self.hotKeyManager = hotKeyManager
        self.settingsWindowPresenter = settingsWindowPresenter
        self.coordinator = coordinator

        state.applyPermissionSnapshot(permissionService.currentSnapshot())
        state.launchAtLoginEnabled = launchAtLoginService.isEnabled

        hotKeyManager.setHandler { [coordinator] in
            coordinator.startCapture()
        }

        registerStoredHotKey(state.hotKey, state: state, manager: hotKeyManager)
    }

    var body: some Scene {
        MenuBarExtra("ClipSight", systemImage: "text.viewfinder") {
            Button {
                coordinator.startCapture()
            } label: {
                Label(appState.isCapturing ? "正在识别" : "截图识别", systemImage: "viewfinder")
            }
            .disabled(appState.isCapturing)

            Divider()

            Text("快捷键：\(appState.shortcutDisplay)")

            if let hotKeyRegistrationError = appState.hotKeyRegistrationError {
                Text(hotKeyRegistrationError)
            }

            if !appState.lastMessage.isEmpty {
                Text(appState.lastMessage)
            }

            Divider()

            Button {
                openSettingsWindow()
            } label: {
                Label("设置...", systemImage: "gearshape")
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
            }
        }
    }

    private func updateHotKey(_ hotKey: HotKey) {
        appState.setHotKey(hotKey)
        registerStoredHotKey(hotKey, state: appState, manager: hotKeyManager)
    }

    private func clearHotKey() {
        appState.clearHotKey()
        appState.hotKeyRegistrationError = nil
        hotKeyManager.unregister()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            appState.launchAtLoginEnabled = launchAtLoginService.isEnabled
        } catch {
            appState.launchAtLoginEnabled = launchAtLoginService.isEnabled
            appState.lastMessage = error.localizedDescription
        }
    }

    private func refreshPermissions() {
        appState.applyPermissionSnapshot(permissionService.currentSnapshot())
        appState.launchAtLoginEnabled = launchAtLoginService.isEnabled
    }

    private func openSettingsWindow() {
        settingsWindowPresenter.show {
            SettingsView(
                appState: appState,
                onRecordHotKey: updateHotKey,
                onClearHotKey: clearHotKey,
                onSetLaunchAtLogin: setLaunchAtLogin,
                onRefreshPermissions: refreshPermissions,
                onOpenScreenRecordingSettings: permissionService.openScreenRecordingSettings,
                onOpenAccessibilitySettings: permissionService.openAccessibilitySettings
            )
        }
    }

    private func registerStoredHotKey(
        _ hotKey: HotKey?,
        state: AppState,
        manager: HotKeyManager
    ) {
        do {
            try manager.register(hotKey)
            state.hotKeyRegistrationError = nil
        } catch {
            state.hotKeyRegistrationError = error.localizedDescription
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
