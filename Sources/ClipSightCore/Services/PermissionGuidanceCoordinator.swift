import AppKit
import Foundation
import OSLog

@MainActor
public final class PermissionGuidanceCoordinator {
    private let appState: AppState
    private let permissionService: any PermissionServicing
    private let launchAtLoginService: any LaunchAtLoginManaging
    private let promptStore: InitialPermissionPromptStore
    private let notificationCenter: NotificationCenter
    private let openSettingsWindow: @MainActor () -> Void
    private let logger = Logger(subsystem: ClipSightLogging.subsystem, category: ClipSightLogging.Category.permissions)
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
        logger.info("Opening initial permission guidance because screen recording is missing")
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
            guard let coordinator = self else {
                return
            }

            Task { @MainActor [coordinator] in
                coordinator.handleApplicationDidBecomeActive()
            }
        }
    }

    public func handleApplicationDidBecomeActive() {
        refreshState()
    }

    public func refreshState() {
        appState.applyPermissionSnapshot(permissionService.currentSnapshot())
        appState.launchAtLoginEnabled = launchAtLoginService.isEnabled
        logger.info("Permission state refreshed screenRecording=\(self.appState.screenRecordingPermission.isGranted, privacy: .public) accessibility=\(self.appState.accessibilityPermission.isGranted, privacy: .public)")
    }
}
