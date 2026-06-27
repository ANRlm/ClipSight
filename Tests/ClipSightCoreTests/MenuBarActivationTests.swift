import AppKit
import Foundation
import XCTest
@testable import ClipSightCore

final class MenuBarActivationTests: XCTestCase {
    func testAppUsesAppKitStatusItemInsteadOfSwiftUIMenuBarExtra() throws {
        let source = try String(contentsOfFile: "Sources/ClipSight/ClipSightApp.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("StatusMenuController("))
        XCTAssertFalse(source.contains("MenuBarExtra("))
    }

    func testAppLaunchesWithNonActivatingPolicyForStatusMenuUse() throws {
        let source = try String(contentsOfFile: "Sources/ClipSight/ClipSightApp.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("NSApp.setActivationPolicy(.prohibited)"))
        XCTAssertFalse(source.contains("func applicationDidFinishLaunching(_ notification: Notification) {\n        NSApp.setActivationPolicy(.accessory)"))
    }

    func testAppDoesNotRegisterEmptySwiftUISettingsScene() throws {
        let source = try String(contentsOfFile: "Sources/ClipSight/ClipSightApp.swift", encoding: .utf8)

        XCTAssertFalse(source.contains("Settings {\n            EmptyView()"))
        XCTAssertFalse(source.contains("var body: some Scene"))
    }

    func testOpenSettingsActionIsDeferredWithMainActorTask() throws {
        let source = try String(contentsOfFile: "Sources/ClipSightCore/Support/StatusMenuController.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("@objc private func handleOpenSettings(_ sender: NSMenuItem)"))
        XCTAssertTrue(source.contains("Task { @MainActor [actions] in"))
        XCTAssertTrue(source.contains("actions.openSettings()"))
    }

    @MainActor
    func testStatusMenuRebuildsLocalizedItemsAndDisablesCaptureWhileCapturing() throws {
        try skipIfRunningInCI()

        let appState = makeAppState(languageSelection: .english)
        appState.isCapturing = true

        let controller = StatusMenuController(
            appState: appState,
            actions: StatusMenuActions(
                captureOCR: {},
                openSettings: {},
                copyDiagnostics: {},
                quit: {}
            )
        )
        defer {
            controller.invalidate()
        }

        controller.menuWillOpen(controller.menuForTesting)
        let menu = controller.menuForTesting
        let titles = menu.items.map(\.title)

        XCTAssertEqual(menu.items.first?.title, "Recognizing")
        XCTAssertEqual(menu.items.first?.isEnabled, false)
        XCTAssertTrue(titles.contains("Shortcut: Not set"))
        XCTAssertTrue(titles.contains("Settings..."))
        XCTAssertTrue(titles.contains("Copy Diagnostics"))
        XCTAssertTrue(titles.contains("Quit"))
    }

    @MainActor
    func testStatusMenuActionsInvokeConfiguredHandlers() throws {
        try skipIfRunningInCI()

        let appState = makeAppState(languageSelection: .english)
        var didCapture = false
        var didOpenSettings = false
        var didCopyDiagnostics = false
        var didQuit = false

        let controller = StatusMenuController(
            appState: appState,
            actions: StatusMenuActions(
                captureOCR: { didCapture = true },
                openSettings: { didOpenSettings = true },
                copyDiagnostics: { didCopyDiagnostics = true },
                quit: { didQuit = true }
            )
        )
        defer {
            controller.invalidate()
        }

        controller.menuWillOpen(controller.menuForTesting)
        try performMenuItem(titled: "Capture OCR", in: controller.menuForTesting)
        try performMenuItem(titled: "Settings...", in: controller.menuForTesting)
        try performMenuItem(titled: "Copy Diagnostics", in: controller.menuForTesting)
        try performMenuItem(titled: "Quit", in: controller.menuForTesting)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(didCapture)
        XCTAssertTrue(didOpenSettings)
        XCTAssertTrue(didCopyDiagnostics)
        XCTAssertTrue(didQuit)
    }

    @MainActor
    func testOpenSettingsActionIsDeferredUntilStatusMenuCloses() throws {
        try skipIfRunningInCI()

        let appState = makeAppState(languageSelection: .english)
        var didOpenSettings = false

        let controller = StatusMenuController(
            appState: appState,
            actions: StatusMenuActions(
                captureOCR: {},
                openSettings: { didOpenSettings = true },
                copyDiagnostics: {},
                quit: {}
            )
        )
        defer {
            controller.invalidate()
        }

        controller.menuWillOpen(controller.menuForTesting)
        try performMenuItem(titled: "Settings...", in: controller.menuForTesting)

        XCTAssertFalse(didOpenSettings)

        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(didOpenSettings)
    }

    private func skipIfRunningInCI() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["CI"] == "true",
            "Runtime status item tests require a local WindowServer; CI keeps source-level coverage."
        )
    }

    @MainActor
    private func makeAppState(languageSelection: AppLanguageSelection) -> AppState {
        let suiteName = "ClipSight.MenuBarActivationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let appState = AppState(
            hotKeyStore: HotKeyStore(userDefaults: defaults),
            hudPlacementStore: HUDPlacementStore(userDefaults: defaults),
            languageStore: AppLanguageStore(userDefaults: defaults)
        )
        appState.setLanguageSelection(languageSelection)
        return appState
    }

    @MainActor
    private func performMenuItem(titled title: String, in menu: NSMenu) throws {
        let item = try XCTUnwrap(menu.items.first { $0.title == title })
        let action = try XCTUnwrap(item.action)

        NSApp.sendAction(action, to: item.target, from: item)
    }
}
