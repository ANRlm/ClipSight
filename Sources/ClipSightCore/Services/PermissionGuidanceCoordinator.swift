import AppKit
import Foundation

@MainActor
public final class PermissionGuidanceCoordinator {
    private let appState: AppState
    private let permissionService: any PermissionServicing
    private let launchAtLoginService: any LaunchAtLoginManaging
    private let promptStore: InitialPermissionPromptStore
    private let notificationCenter: NotificationCenter
    private let openSettingsWindow: @MainActor () -> Void
    private var activationObserver: NSObjectProtocol?

    public init(
        appState: AppState,
        permissionService: any PermissionServicing,
        launchAtLoginService: any LaunchAtLoginManaging,
        promptStore: InitialPermissionPromptStore = InitialPermissionPromptStore(),
        notificationCenter: NotificationCenter = .default,
        openSettingsWindow: @escaping @MainActor () -> Void
    ) {
        self.appState = appState
        self.permissionService = permissionService
        self.launchAtLoginService = launchAtLoginService
        self.promptStore = promptStore
        self.notificationCenter = notificationCenter
        self.openSettingsWindow = openSettingsWindow
    }

    public func handleLaunch() {
        refreshState()

        guard !appState.screenRecordingPermission.isGranted,
              !promptStore.hasShownInitialScreenRecordingGuidance else {
            return
        }

        promptStore.markInitialScreenRecordingGuidanceShown()
        openSettingsWindow()
    }

    public func startObservingApplicationActivation() {
        guard activationObserver == nil else {
            return
        }

        activationObserver = notificationCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleApplicationDidBecomeActive()
            }
        }
    }

    public func handleApplicationDidBecomeActive() {
        refreshState()
    }

    public func refreshState() {
        appState.applyPermissionSnapshot(permissionService.currentSnapshot())
        appState.launchAtLoginEnabled = launchAtLoginService.isEnabled
    }
}
