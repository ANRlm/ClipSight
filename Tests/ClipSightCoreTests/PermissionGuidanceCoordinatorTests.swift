import AppKit
import Foundation
import XCTest
@testable import ClipSightCore

@MainActor
final class PermissionGuidanceCoordinatorTests: XCTestCase {
    func testOpensSettingsWindowOnceWhenFirstLaunchIsMissingScreenRecordingPermission() {
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

        XCTAssertEqual(settingsOpenCount, 1)
        XCTAssertFalse(permissionService.didOpenScreenRecordingSettings)
        XCTAssertTrue(store.hasShownInitialScreenRecordingGuidance)
        XCTAssertFalse(appState.screenRecordingPermission.isGranted)
    }

    func testDoesNotRepeatFirstLaunchPromptAfterItHasAlreadyBeenShown() {
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

        XCTAssertEqual(settingsOpenCount, 0)
        XCTAssertFalse(permissionService.didOpenScreenRecordingSettings)
    }

    func testRefreshesPermissionAndLaunchStatusWhenApplicationBecomesActive() async throws {
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

        XCTAssertTrue(appState.screenRecordingPermission.isGranted)
        XCTAssertTrue(appState.launchAtLoginEnabled)
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
