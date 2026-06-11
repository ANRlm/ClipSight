import AppKit
import Foundation
import Testing
@testable import ClipSightCore

@MainActor
struct PermissionGuidanceCoordinatorTests {
    @Test
    func opensSettingsWindowOnceWhenFirstLaunchIsMissingScreenRecordingPermission() {
        let appState = AppState()
        let permissionService = MutablePermissionService(screenRecordingGranted: false)
        let launchAtLoginService = StubLaunchAtLoginManaging(isEnabled: false)
        let store = InitialPermissionPromptStore(userDefaults: temporaryDefaults())
        var settingsOpenCount = 0
        let coordinator = PermissionGuidanceCoordinator(
            appState: appState,
            permissionService: permissionService,
            launchAtLoginService: launchAtLoginService,
            promptStore: store
        ) {
            settingsOpenCount += 1
        }

        coordinator.handleLaunch()

        #expect(settingsOpenCount == 1)
        #expect(!permissionService.didOpenScreenRecordingSettings)
        #expect(store.hasShownInitialScreenRecordingGuidance)
        #expect(!appState.screenRecordingPermission.isGranted)
    }

    @Test
    func doesNotRepeatFirstLaunchPromptAfterItHasAlreadyBeenShown() {
        let appState = AppState()
        let permissionService = MutablePermissionService(screenRecordingGranted: false)
        let launchAtLoginService = StubLaunchAtLoginManaging(isEnabled: false)
        let store = InitialPermissionPromptStore(userDefaults: temporaryDefaults())
        store.markInitialScreenRecordingGuidanceShown()
        var settingsOpenCount = 0
        let coordinator = PermissionGuidanceCoordinator(
            appState: appState,
            permissionService: permissionService,
            launchAtLoginService: launchAtLoginService,
            promptStore: store
        ) {
            settingsOpenCount += 1
        }

        coordinator.handleLaunch()

        #expect(settingsOpenCount == 0)
        #expect(!permissionService.didOpenScreenRecordingSettings)
    }

    @Test
    func refreshesPermissionAndLaunchStatusWhenApplicationBecomesActive() async throws {
        let appState = AppState()
        let permissionService = MutablePermissionService(screenRecordingGranted: false)
        let launchAtLoginService = StubLaunchAtLoginManaging(isEnabled: false)
        let store = InitialPermissionPromptStore(userDefaults: temporaryDefaults())
        let notificationCenter = NotificationCenter()
        let coordinator = PermissionGuidanceCoordinator(
            appState: appState,
            permissionService: permissionService,
            launchAtLoginService: launchAtLoginService,
            promptStore: store,
            notificationCenter: notificationCenter
        ) {}

        coordinator.startObservingApplicationActivation()
        permissionService.screenRecordingGranted = true
        launchAtLoginService.isEnabled = true
        notificationCenter.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        try await Task.sleep(nanoseconds: 20_000_000)

        #expect(appState.screenRecordingPermission.isGranted)
        #expect(appState.launchAtLoginEnabled)
    }
}

private func temporaryDefaults() -> UserDefaults {
    let suiteName = "ClipSight.PermissionGuidanceCoordinatorTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

@MainActor
private final class MutablePermissionService: PermissionServicing {
    var screenRecordingGranted: Bool
    private(set) var didOpenScreenRecordingSettings = false
    private(set) var didOpenAccessibilitySettings = false

    init(screenRecordingGranted: Bool) {
        self.screenRecordingGranted = screenRecordingGranted
    }

    func currentSnapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            screenRecording: PermissionStatus(
                title: "屏幕录制",
                detail: "允许读取截图",
                isGranted: screenRecordingGranted
            ),
            accessibility: PermissionStatus(
                title: "辅助功能",
                missingLabel: "可选",
                detail: "当前快捷键实现不依赖辅助功能权限",
                isGranted: true,
                isRequired: false
            )
        )
    }

    func openScreenRecordingSettings() {
        didOpenScreenRecordingSettings = true
    }

    func openAccessibilitySettings() {
        didOpenAccessibilitySettings = true
    }
}

@MainActor
private final class StubLaunchAtLoginManaging: LaunchAtLoginManaging {
    var isEnabled: Bool

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    func setEnabled(_ enabled: Bool) throws {
        isEnabled = enabled
    }
}
