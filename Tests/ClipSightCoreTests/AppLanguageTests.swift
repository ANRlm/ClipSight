import XCTest
@testable import ClipSightCore

final class AppLanguageTests: XCTestCase {
    func testLanguageSelectionDefaultsToSystem() {
        let suiteName = "ClipSight.AppLanguageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = AppLanguageStore(userDefaults: defaults)

        XCTAssertEqual(store.load(), .system)
    }

    func testLanguageSelectionStoreSaveLoadAndInvalidFallback() {
        let suiteName = "ClipSight.AppLanguageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = AppLanguageStore(userDefaults: defaults)
        store.save(.english)

        XCTAssertEqual(store.load(), .english)

        defaults.set("invalid", forKey: AppLanguageStore.storageKey)

        XCTAssertEqual(store.load(), .system)
    }

    func testSystemLanguageSelectionResolvesChinesePreferredLanguages() {
        XCTAssertEqual(
            AppLanguageSelection.system.resolved(preferredLanguages: ["zh-Hans-US", "en-US"]),
            .chinese
        )
    }

    func testSystemLanguageSelectionFallsBackToEnglishForNonChineseSystems() {
        XCTAssertEqual(
            AppLanguageSelection.system.resolved(preferredLanguages: ["fr-FR", "en-US"]),
            .english
        )
    }

    func testAppStringsExposeChineseAndEnglishMenuAndHUDCopy() {
        let chinese = AppStrings(language: .chinese)
        let english = AppStrings(language: .english)

        XCTAssertEqual(chinese.captureActionTitle, "截图识别")
        XCTAssertEqual(english.captureActionTitle, "Capture OCR")
        XCTAssertEqual(chinese.hudSuccessMessage, "已复制")
        XCTAssertEqual(english.hudSuccessMessage, "Copied")
        XCTAssertEqual(chinese.copiedLinesMessage(2), "已复制 2 行文本")
        XCTAssertEqual(english.copiedLinesMessage(2), "Copied 2 lines")
    }

    func testPermissionSnapshotUsesSelectedLanguage() {
        let snapshot = AppStrings(language: .english).permissionSnapshot(
            screenRecordingGranted: true,
            accessibilityGranted: false
        )

        XCTAssertEqual(snapshot.screenRecording.title, "Screen Recording")
        XCTAssertEqual(snapshot.screenRecording.statusLabel, "Granted")
        XCTAssertEqual(snapshot.accessibility.title, "Accessibility")
        XCTAssertEqual(snapshot.accessibility.statusLabel, "Optional")
    }

    @MainActor
    func testAppStateLanguageSelectionPersistsAndRelocalizesState() {
        let suiteName = "ClipSight.AppLanguageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let appState = AppState(
            hotKeyStore: HotKeyStore(userDefaults: defaults),
            hudPlacementStore: HUDPlacementStore(userDefaults: defaults),
            languageStore: AppLanguageStore(userDefaults: defaults),
            preferredLanguages: { ["zh-Hans"] }
        )

        appState.setLanguageSelection(.english)

        XCTAssertEqual(appState.languageSelection, .english)
        XCTAssertEqual(AppLanguageStore(userDefaults: defaults).load(), .english)
        XCTAssertEqual(appState.lastMessage, "Ready")
        XCTAssertEqual(appState.screenRecordingPermission.title, "Screen Recording")
        XCTAssertEqual(appState.shortcutDisplay, "Not set")
    }
}
