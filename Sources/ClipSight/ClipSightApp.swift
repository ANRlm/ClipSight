import AppKit
import ClipSightCore
import OSLog
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
    private let statusMenuController: StatusMenuController

    init() {
        let state = AppState()
        let permissionService = PermissionService()
        let launchAtLoginService = LaunchAtLoginService()
        let hotKeyManager = HotKeyManager()
        let settingsWindowPresenter = SettingsWindowPresenter()
        let statusHUDPresenter = StatusHUDPresenter(
            placement: { state.hudPlacement },
            strings: { state.strings }
        )
        let hudPlacementEditorPresenter = HUDPlacementEditorPresenter(
            placement: { state.hudPlacement },
            onPlacementChange: { placement in
                state.setHUDPlacement(placement)
            },
            strings: { state.strings }
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
                state.hotKeyRegistrationError = state.strings.errorMessage(for: error)
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
                state.lastMessage = state.strings.errorMessage(for: error)
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
                state.lastMessage = state.strings.copiedDiagnosticsMessage
            } catch {
                state.lastMessage = state.strings.errorMessage(for: error)
            }
        }

        let openSettingsWindow: @MainActor () -> Void = {
            settingsWindowPresenter.show(title: state.strings.settingsWindowTitle) {
                SettingsView(
                    appState: state,
                    onRecordHotKey: updateHotKey,
                    onClearHotKey: clearHotKey,
                    onSetLaunchAtLogin: setLaunchAtLogin,
                    onSetLanguageSelection: state.setLanguageSelection,
                    onEditHUDPlacement: hudPlacementEditorPresenter.show,
                    onResetHUDPlacement: state.resetHUDPlacement,
                    onRefreshPermissions: refreshPermissions,
                    onOpenScreenRecordingSettings: permissionService.openScreenRecordingSettings,
                    onOpenAccessibilitySettings: permissionService.openAccessibilitySettings
                )
            }
        }

        let isDevelopmentQAMenuEnabled = ProcessInfo.processInfo.environment["CLIPSIGHT_ENABLE_QA_MENU"] == "1"
        let statusMenuController = StatusMenuController(
            appState: state,
            actions: StatusMenuActions(
                captureOCR: coordinator.startCapture,
                openSettings: openSettingsWindow,
                copyDiagnostics: copyDiagnostics,
                quit: {
                    NSApplication.shared.terminate(nil)
                },
                showSuccessHUD: {
                    statusHUDPresenter.show(.success)
                },
                showNoTextHUD: {
                    statusHUDPresenter.show(.noText)
                },
                showFailureHUD: {
                    statusHUDPresenter.show(.failure)
                },
                adjustHUDPosition: hudPlacementEditorPresenter.show
            ),
            isDevelopmentQAMenuEnabled: isDevelopmentQAMenuEnabled
        )

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
        self.statusMenuController = statusMenuController

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
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: ClipSightLogging.subsystem, category: ClipSightLogging.Category.appLifecycle)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
        logger.info("ClipSight launched with prohibited activation policy")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
