import SwiftUI
import XCTest
@testable import ClipSightCore

@MainActor
final class SettingsViewTests: XCTestCase {
    func testSettingsViewBodyUsesScrollViewForOverflowingContent() {
        let appState = AppState(
            hotKeyStore: HotKeyStore(userDefaults: temporaryDefaults()),
            hudPlacementStore: HUDPlacementStore(userDefaults: temporaryDefaults())
        )
        let settingsView = SettingsView(
            appState: appState,
            onRecordHotKey: { _ in },
            onClearHotKey: {},
            onSetLaunchAtLogin: { _ in },
            onEditHUDPlacement: {},
            onResetHUDPlacement: {},
            onRefreshPermissions: {},
            onOpenScreenRecordingSettings: {},
            onOpenAccessibilitySettings: {}
        )

        XCTAssertTrue(
            String(describing: type(of: settingsView.body)).contains("ScrollView"),
            "SettingsView should use ScrollView so overflowing settings remain reachable in the fixed settings window."
        )
    }
}

private func temporaryDefaults() -> UserDefaults {
    let suiteName = "ClipSight.SettingsViewTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
