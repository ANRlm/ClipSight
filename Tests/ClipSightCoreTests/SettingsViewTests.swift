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
            onSetLanguageSelection: { _ in },
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

    func testSettingsViewCanRenderLanguageSelectionEntry() {
        let appState = AppState(
            hotKeyStore: HotKeyStore(userDefaults: temporaryDefaults()),
            hudPlacementStore: HUDPlacementStore(userDefaults: temporaryDefaults()),
            languageStore: AppLanguageStore(userDefaults: temporaryDefaults()),
            preferredLanguages: { ["en-US"] }
        )
        let settingsView = SettingsView(
            appState: appState,
            onRecordHotKey: { _ in },
            onClearHotKey: {},
            onSetLaunchAtLogin: { _ in },
            onSetLanguageSelection: { appState.setLanguageSelection($0) },
            onEditHUDPlacement: {},
            onResetHUDPlacement: {},
            onRefreshPermissions: {},
            onOpenScreenRecordingSettings: {},
            onOpenAccessibilitySettings: {}
        )

        _ = settingsView.body

        XCTAssertEqual(appState.strings.languageTitle, "Language")
        appState.setLanguageSelection(.chinese)
        XCTAssertEqual(appState.strings.languageTitle, "语言")
    }
}

private func temporaryDefaults() -> UserDefaults {
    let suiteName = "ClipSight.SettingsViewTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
