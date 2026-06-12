import Foundation
import XCTest
@testable import ClipSightCore

final class HotKeyStoreTests: XCTestCase {
    func testSaveLoadAndClearHotKey() throws {
        let suiteName = "ClipSight.HotKeyStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = HotKeyStore(userDefaults: defaults)
        let hotKey = HotKey(
            keyCode: 8,
            carbonModifiers: HotKeyModifier.command.carbonFlag | HotKeyModifier.shift.carbonFlag,
            keyEquivalent: "C"
        )

        store.save(hotKey)

        XCTAssertEqual(store.load(), hotKey)

        store.clear()

        XCTAssertNil(store.load())
    }

    func testDisplayStringUsesModifierOrderAndKeyEquivalent() {
        let hotKey = HotKey(
            keyCode: 9,
            carbonModifiers: HotKeyModifier.control.carbonFlag
                | HotKeyModifier.option.carbonFlag
                | HotKeyModifier.command.carbonFlag,
            keyEquivalent: "V"
        )

        XCTAssertEqual(hotKey.displayString, "⌃⌥⌘V")
    }
}
