import AppKit
import SwiftUI
import XCTest
@testable import ClipSightCore

@MainActor
final class SettingsWindowPresenterTests: XCTestCase {
    func testShowCreatesAndReusesSettingsWindow() {
        let presenter = SettingsWindowPresenter(
            title: "ClipSight Test Settings",
            size: NSSize(width: 320, height: 240)
        )
        defer {
            presenter.close()
        }

        presenter.show {
            Text("First")
        }

        let firstWindow = presenter.windowForTesting

        XCTAssertNotNil(firstWindow)
        XCTAssertEqual(firstWindow?.isVisible, true)
        XCTAssertEqual(firstWindow?.title, "ClipSight Test Settings")

        presenter.show {
            Text("Second")
        }

        XCTAssertTrue(presenter.windowForTesting === firstWindow)
        XCTAssertEqual(presenter.windowForTesting?.isVisible, true)
    }

    func testShowCreatesResizableSettingsWindow() {
        let presenter = SettingsWindowPresenter(
            title: "ClipSight Test Settings",
            size: NSSize(width: 660, height: 620)
        )
        defer {
            presenter.close()
        }

        presenter.show {
            Text("Resizable")
        }

        let window = presenter.windowForTesting

        XCTAssertEqual(window?.styleMask.contains(.resizable), true)
        XCTAssertLessThanOrEqual(window?.minSize.width ?? .greatestFiniteMagnitude, 660)
        XCTAssertLessThanOrEqual(window?.minSize.height ?? .greatestFiniteMagnitude, 620)
    }

    func testShowCreatesSettingsWindowWithAdaptiveTitlebarChrome() throws {
        let presenter = SettingsWindowPresenter(
            title: "ClipSight Test Settings",
            size: NSSize(width: 660, height: 620)
        )
        defer {
            presenter.close()
        }

        presenter.show {
            Text("Adaptive chrome")
        }

        let window = try XCTUnwrap(presenter.windowForTesting)

        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.backgroundColor, NSColor.windowBackgroundColor)
        XCTAssertNil(window.appearance)
    }

    func testShowTemporarilyActivatesAppAndCloseReturnsToStatusMenuOnlyPolicy() {
        var activationCount = 0
        var returnToStatusMenuOnlyCount = 0
        let presenter = SettingsWindowPresenter(
            title: "ClipSight Test Settings",
            size: NSSize(width: 660, height: 620),
            activateApplication: {
                activationCount += 1
            },
            returnToStatusMenuOnly: {
                returnToStatusMenuOnlyCount += 1
            }
        )

        presenter.show {
            Text("Activation")
        }

        XCTAssertEqual(activationCount, 1)
        XCTAssertEqual(returnToStatusMenuOnlyCount, 0)

        presenter.close()

        XCTAssertEqual(returnToStatusMenuOnlyCount, 1)
    }

    func testDefaultActivationUsesRunningApplicationActivationOptions() throws {
        let source = try String(
            contentsOfFile: "Sources/ClipSightCore/Support/SettingsWindowPresenter.swift",
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("NSRunningApplication.current.activate"))
        XCTAssertTrue(source.contains(".activateAllWindows"))
        XCTAssertTrue(source.contains(".activateIgnoringOtherApps"))
    }
}
