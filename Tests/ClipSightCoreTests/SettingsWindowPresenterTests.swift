import AppKit
import SwiftUI
import Testing
@testable import ClipSightCore

@MainActor
struct SettingsWindowPresenterTests {
    @Test
    func showCreatesAndReusesSettingsWindow() {
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

        #expect(firstWindow != nil)
        #expect(firstWindow?.isVisible == true)
        #expect(firstWindow?.title == "ClipSight Test Settings")

        presenter.show {
            Text("Second")
        }

        #expect(presenter.windowForTesting === firstWindow)
        #expect(presenter.windowForTesting?.isVisible == true)
    }
}
