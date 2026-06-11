import Foundation
import Testing
@testable import ClipSightCore

struct HotKeyStoreTests {
    @Test
    func saveLoadAndClearHotKey() throws {
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

        #expect(store.load() == hotKey)

        store.clear()

        #expect(store.load() == nil)
    }

    @Test
    func displayStringUsesModifierOrderAndKeyEquivalent() {
        let hotKey = HotKey(
            keyCode: 9,
            carbonModifiers: HotKeyModifier.control.carbonFlag
                | HotKeyModifier.option.carbonFlag
                | HotKeyModifier.command.carbonFlag,
            keyEquivalent: "V"
        )

        #expect(hotKey.displayString == "⌃⌥⌘V")
    }
}
