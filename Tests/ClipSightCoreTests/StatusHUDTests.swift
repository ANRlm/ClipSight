import AppKit
import XCTest
@testable import ClipSightCore

final class StatusHUDTests: XCTestCase {
    func testDefaultHUDPlacementIsLowerCenter() {
        XCTAssertEqual(HUDPlacement.default, HUDPlacement(x: 0.5, y: 0.34))
    }

    func testHUDPlacementStoreSaveLoadAndClear() {
        let suiteName = "ClipSight.StatusHUDTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = HUDPlacementStore(userDefaults: defaults)
        let placement = HUDPlacement(x: 0.24, y: 0.72)

        XCTAssertEqual(store.load(), .default)

        store.save(placement)

        XCTAssertEqual(store.load(), placement)

        store.clear()

        XCTAssertEqual(store.load(), .default)
    }

    @MainActor
    func testAppStateCanResetHUDPlacementToDefault() {
        let suiteName = "ClipSight.StatusHUDTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let appState = AppState(
            hotKeyStore: HotKeyStore(userDefaults: defaults),
            hudPlacementStore: HUDPlacementStore(userDefaults: defaults)
        )
        appState.setHUDPlacement(HUDPlacement(x: 0.2, y: 0.8))

        appState.resetHUDPlacement()

        XCTAssertEqual(appState.hudPlacement, .default)
        XCTAssertEqual(HUDPlacementStore(userDefaults: defaults).load(), .default)
    }

    func testHUDPlacementStoreFallsBackToDefaultForInvalidValue() {
        let suiteName = "ClipSight.StatusHUDTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let invalidJSON = Data(#"{"x":2.3,"y":-0.7}"#.utf8)
        defaults.set(invalidJSON, forKey: HUDPlacementStore.storageKey)

        XCTAssertEqual(HUDPlacementStore(userDefaults: defaults).load(), .default)
    }

    func testHUDPlacementStoreMigratesLegacyPreset() {
        let suiteName = "ClipSight.StatusHUDTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("center", forKey: HUDPlacementStore.legacyPositionStorageKey)

        XCTAssertEqual(HUDPlacementStore(userDefaults: defaults).load(), HUDPlacement(x: 0.5, y: 0.5))
    }

    func testHUDPlacementStoreClearRemovesLegacyPreset() {
        let suiteName = "ClipSight.StatusHUDTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("center", forKey: HUDPlacementStore.legacyPositionStorageKey)

        let store = HUDPlacementStore(userDefaults: defaults)
        store.clear()

        XCTAssertEqual(store.load(), .default)
    }

    func testStatusHUDOriginIsClampedInsideVisibleFrame() {
        let visibleFrame = NSRect(x: 40, y: 80, width: 500, height: 360)
        let windowSize = StatusHUDPresenter.defaultWindowSize

        for placement in [HUDPlacement(x: 0, y: 0), .default, HUDPlacement(x: 1, y: 1)] {
            let origin = StatusHUDPresenter.origin(
                for: placement,
                in: visibleFrame,
                windowSize: windowSize
            )

            XCTAssertGreaterThanOrEqual(origin.x, visibleFrame.minX)
            XCTAssertGreaterThanOrEqual(origin.y, visibleFrame.minY)
            XCTAssertLessThanOrEqual(origin.x + windowSize.width, visibleFrame.maxX)
            XCTAssertLessThanOrEqual(origin.y + windowSize.height, visibleFrame.maxY)
        }
    }

    func testHUDPlacementSnapsToHorizontalCenterWithinThreshold() {
        let snapped = HUDPlacement(x: 0.512, y: 0.62).snappedToHorizontalCenter(
            in: 1_000,
            threshold: 18
        )
        let unsnapped = HUDPlacement(x: 0.54, y: 0.62).snappedToHorizontalCenter(
            in: 1_000,
            threshold: 18
        )

        XCTAssertEqual(snapped, HUDPlacement(x: 0.5, y: 0.62))
        XCTAssertEqual(unsnapped, HUDPlacement(x: 0.54, y: 0.62))
    }

    func testHUDPlacementDraftFinishCommitsAndCancelRestoresInitialPlacement() {
        var draft = HUDPlacementDraft(initialPlacement: .default)
        draft.update(HUDPlacement(x: 0.72, y: 0.18))

        XCTAssertEqual(draft.finishedPlacement, HUDPlacement(x: 0.72, y: 0.18))
        XCTAssertEqual(draft.cancelledPlacement, .default)
    }

    func testStatusHUDDefaultWindowSizeIsCompact() {
        XCTAssertEqual(StatusHUDPresenter.defaultWindowSize, NSSize(width: 280, height: 56))
    }

    func testStatusHUDWindowSizeIncludesTransparentShadowPadding() {
        XCTAssertGreaterThan(StatusHUDPresenter.windowSize.width, StatusHUDPresenter.defaultWindowSize.width)
        XCTAssertGreaterThan(StatusHUDPresenter.windowSize.height, StatusHUDPresenter.defaultWindowSize.height)
    }

    @MainActor
    func testStatusHUDContainerUsesCapsuleMaskAndShadowPath() {
        let container = StatusHUDContainerView(presentation: .success)
        container.frame = NSRect(origin: .zero, size: StatusHUDPresenter.windowSize)
        container.layoutSubtreeIfNeeded()

        XCTAssertTrue(container.hasCapsuleMaterialMask)
        XCTAssertTrue(container.hasMaterialMaskImage)
        XCTAssertTrue(container.hasCapsuleShadowPath)
        XCTAssertFalse(container.layer?.masksToBounds ?? true)
    }

    func testPlacementEditorBackdropDimsScreenWithoutHidingPreview() {
        XCTAssertEqual(HUDPlacementEditorPresenter.backdropOpacity, 0.28, accuracy: 0.001)
        XCTAssertGreaterThan(HUDPlacementEditorPresenter.backdropOpacity, 0.2)
        XCTAssertLessThan(HUDPlacementEditorPresenter.backdropOpacity, 0.4)
    }

    func testPlacementEditorPreviewUsesForegroundSurface() {
        XCTAssertEqual(HUDPlacementEditorPresenter.previewSurface, .foreground)
        XCTAssertEqual(HUDPlacementEditorPresenter.previewSurfaceOpacity, 1, accuracy: 0.001)
    }

    func testStatusHUDPresentationMessagesAreStatusOnly() {
        XCTAssertEqual(StatusHUDPresentation.success.message, "已复制")
        XCTAssertEqual(StatusHUDPresentation.noText.message, "未识别到文本")
        XCTAssertEqual(StatusHUDPresentation.failure.message, "识别失败")
    }
}
