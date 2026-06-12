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
    private let statusHUDPresenter: StatusHUDPresenter
    private let hudPlacementEditorPresenter: HUDPlacementEditorPresenter
    private let permissionGuidanceCoordinator: PermissionGuidanceCoordinator
    private let openSettingsWindowAction: @MainActor () -> Void
    private let copyDiagnosticsAction: @MainActor () -> Void
    private let isDevelopmentQAMenuEnabled: Bool

    init() {
        let state = AppState()
        let permissionService = PermissionService()
        let launchAtLoginService = LaunchAtLoginService()
        let hotKeyManager = HotKeyManager()
        let settingsWindowPresenter = SettingsWindowPresenter()
        let statusHUDPresenter = StatusHUDPresenter(placement: { state.hudPlacement })
        let hudPlacementEditorPresenter = HUDPlacementEditorPresenter(
            placement: { state.hudPlacement },
            onPlacementChange: { placement in
                state.setHUDPlacement(placement)
            }
        )
        let coordinator = CaptureOCRCoordinator(
            appState: state,
            permissionService: permissionService,
            screenCaptureService: ScreenCaptureService(),
            ocrService: OCRService(),
            clipboardService: ClipboardService(),
            temporaryFileCleaner: TemporaryFileCleaner(),
            statusHUDPresenter: statusHUDPresenter
        )

        func registerHotKey(_ hotKey: HotKey?) {
            do {
                try hotKeyManager.register(hotKey)
                state.hotKeyRegistrationError = nil
            } catch {
                state.hotKeyRegistrationError = error.localizedDescription
            }
        }

        let updateHotKey: (HotKey) -> Void = { hotKey in
            state.setHotKey(hotKey)
            registerHotKey(hotKey)
        }

        let clearHotKey: () -> Void = {
            state.clearHotKey()
            state.hotKeyRegistrationError = nil
            hotKeyManager.unregister()
        }

        let setLaunchAtLogin: (Bool) -> Void = { enabled in
            do {
                try launchAtLoginService.setEnabled(enabled)
                state.launchAtLoginEnabled = launchAtLoginService.isEnabled
            } catch {
                state.launchAtLoginEnabled = launchAtLoginService.isEnabled
                state.lastMessage = error.localizedDescription
            }
        }

        let refreshPermissions: () -> Void = {
            state.applyPermissionSnapshot(permissionService.currentSnapshot())
            state.launchAtLoginEnabled = launchAtLoginService.isEnabled
        }

        let copyDiagnostics: @MainActor () -> Void = {
            let report = DiagnosticReportBuilder.makeReport(appState: state)
            do {
                _ = try ClipboardService().write(report)
                state.lastMessage = "已复制诊断信息"
            } catch {
                state.lastMessage = error.localizedDescription
            }
        }

        let openSettingsWindow: @MainActor () -> Void = {
            settingsWindowPresenter.show {
                SettingsView(
                    appState: state,
                    onRecordHotKey: updateHotKey,
                    onClearHotKey: clearHotKey,
                    onSetLaunchAtLogin: setLaunchAtLogin,
                    onEditHUDPlacement: hudPlacementEditorPresenter.show,
                    onResetHUDPlacement: state.resetHUDPlacement,
                    onRefreshPermissions: refreshPermissions,
                    onOpenScreenRecordingSettings: permissionService.openScreenRecordingSettings,
                    onOpenAccessibilitySettings: permissionService.openAccessibilitySettings
                )
            }
        }

        let permissionGuidanceCoordinator = PermissionGuidanceCoordinator(
            appState: state,
            permissionService: permissionService,
            launchAtLoginService: launchAtLoginService,
            openSettingsWindow: openSettingsWindow
        )

        _appState = StateObject(wrappedValue: state)
        self.permissionService = permissionService
        self.launchAtLoginService = launchAtLoginService
        self.hotKeyManager = hotKeyManager
        self.settingsWindowPresenter = settingsWindowPresenter
        self.statusHUDPresenter = statusHUDPresenter
        self.hudPlacementEditorPresenter = hudPlacementEditorPresenter
        self.coordinator = coordinator
        self.permissionGuidanceCoordinator = permissionGuidanceCoordinator
        self.openSettingsWindowAction = openSettingsWindow
        self.copyDiagnosticsAction = copyDiagnostics
        self.isDevelopmentQAMenuEnabled = ProcessInfo.processInfo.environment["CLIPSIGHT_ENABLE_QA_MENU"] == "1"

        permissionGuidanceCoordinator.refreshState()
        permissionGuidanceCoordinator.startObservingApplicationActivation()

        hotKeyManager.setHandler { [coordinator] in
            coordinator.startCapture()
        }

        registerHotKey(state.hotKey)

        Task { @MainActor in
            permissionGuidanceCoordinator.handleLaunch()
        }
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
                openSettingsWindowAction()
            } label: {
                Label("设置...", systemImage: "gearshape")
            }

            Button {
                copyDiagnosticsAction()
            } label: {
                Label("复制诊断信息", systemImage: "doc.on.doc")
            }

            if isDevelopmentQAMenuEnabled {
                Divider()

                Menu("开发验证") {
                    Button {
                        statusHUDPresenter.show(.success)
                    } label: {
                        Label("显示成功 HUD", systemImage: "checkmark.circle")
                    }

                    Button {
                        statusHUDPresenter.show(.noText)
                    } label: {
                        Label("显示无文本 HUD", systemImage: "exclamationmark.circle")
                    }

                    Button {
                        statusHUDPresenter.show(.failure)
                    } label: {
                        Label("显示失败 HUD", systemImage: "xmark.circle")
                    }

                    Button {
                        hudPlacementEditorPresenter.show()
                    } label: {
                        Label("调整 HUD 位置", systemImage: "cursorarrow.motionlines")
                    }
                }
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
            }
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
