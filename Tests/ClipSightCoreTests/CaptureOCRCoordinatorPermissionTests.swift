import Foundation
import XCTest
@testable import ClipSightCore

@MainActor
final class CaptureOCRCoordinatorPermissionTests: XCTestCase {
    func testOpensScreenRecordingSettingsWhenScreenRecordingPermissionIsMissing() async {
        let appState = AppState()
        let permissionService = StubPermissionService(
            snapshot: PermissionSnapshot(
                screenRecording: PermissionStatus(
                    title: "屏幕录制",
                    detail: "允许读取截图",
                    isGranted: false
                ),
                accessibility: PermissionStatus(
                    title: "辅助功能",
                    detail: "允许快捷键",
                    isGranted: true
                )
            )
        )
        let screenCaptureService = StubScreenCaptureService()
        let hudPresenter = StubStatusHUDPresenter()
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(),
            clipboardService: StubClipboardService(),
            temporaryFileCleaner: StubTemporaryFileCleaner(),
            statusHUDPresenter: hudPresenter
        )

        await coordinator.captureOnce()

        XCTAssertTrue(permissionService.didOpenScreenRecordingSettings)
        XCTAssertFalse(permissionService.didOpenAccessibilitySettings)
        XCTAssertFalse(screenCaptureService.didCapture)
        XCTAssertEqual(appState.lastMessage, "需要屏幕录制权限，已打开系统设置")
        XCTAssertEqual(hudPresenter.shownPresentations, [])
        XCTAssertFalse(appState.isCapturing)
    }

    func testContinuesCaptureWhenOnlyAccessibilityPermissionIsMissing() async {
        let appState = AppState()
        let permissionService = StubPermissionService(
            snapshot: PermissionSnapshot(
                screenRecording: PermissionStatus(
                    title: "屏幕录制",
                    detail: "允许读取截图",
                    isGranted: true
                ),
                accessibility: PermissionStatus(
                    title: "辅助功能",
                    detail: "允许快捷键",
                    isGranted: false
                )
            )
        )
        let screenCaptureService = StubScreenCaptureService()
        let hudPresenter = StubStatusHUDPresenter()
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(),
            clipboardService: StubClipboardService(),
            temporaryFileCleaner: StubTemporaryFileCleaner(),
            statusHUDPresenter: hudPresenter
        )

        await coordinator.captureOnce()

        XCTAssertFalse(permissionService.didOpenScreenRecordingSettings)
        XCTAssertFalse(permissionService.didOpenAccessibilitySettings)
        XCTAssertTrue(screenCaptureService.didCapture)
        XCTAssertEqual(appState.lastMessage, "已取消截图")
        XCTAssertEqual(hudPresenter.shownPresentations, [])
        XCTAssertFalse(appState.isCapturing)
    }

    func testUpdatesMessageWhenTextIsCopied() async {
        let appState = AppState()
        let permissionService = StubPermissionService(
            snapshot: PermissionSnapshot(
                screenRecording: PermissionStatus(
                    title: "屏幕录制",
                    detail: "允许读取截图",
                    isGranted: true
                ),
                accessibility: PermissionStatus(
                    title: "辅助功能",
                    detail: "允许快捷键",
                    isGranted: false,
                    isRequired: false
                )
            )
        )
        let screenCaptureService = StubScreenCaptureService(result: .captured(URL(fileURLWithPath: "/tmp/capture.png")))
        let hudPresenter = StubStatusHUDPresenter()
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(text: "hello\nworld"),
            clipboardService: StubClipboardService(lineCount: 2),
            temporaryFileCleaner: StubTemporaryFileCleaner(),
            statusHUDPresenter: hudPresenter
        )

        await coordinator.captureOnce()

        XCTAssertEqual(appState.lastMessage, "已复制 2 行文本")
        XCTAssertEqual(hudPresenter.shownPresentations, [.success])
        XCTAssertFalse(appState.isCapturing)
    }

    func testUpdatesEnglishMessageWhenTextIsCopiedInEnglishMode() async {
        let defaults = temporaryDefaults()
        let appState = AppState(
            hotKeyStore: HotKeyStore(userDefaults: defaults),
            hudPlacementStore: HUDPlacementStore(userDefaults: defaults),
            languageStore: AppLanguageStore(userDefaults: defaults),
            preferredLanguages: { ["zh-Hans"] }
        )
        appState.setLanguageSelection(.english)
        let permissionService = StubPermissionService(
            snapshot: PermissionSnapshot(
                screenRecording: PermissionStatus(
                    title: "屏幕录制",
                    detail: "允许读取截图",
                    isGranted: true
                ),
                accessibility: PermissionStatus(
                    title: "辅助功能",
                    detail: "允许快捷键",
                    isGranted: false,
                    isRequired: false
                )
            )
        )
        let screenCaptureService = StubScreenCaptureService(result: .captured(URL(fileURLWithPath: "/tmp/capture.png")))
        let hudPresenter = StubStatusHUDPresenter()
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(text: "hello\nworld"),
            clipboardService: StubClipboardService(lineCount: 2),
            temporaryFileCleaner: StubTemporaryFileCleaner(),
            statusHUDPresenter: hudPresenter
        )

        await coordinator.captureOnce()

        XCTAssertEqual(appState.lastMessage, "Copied 2 lines")
        XCTAssertEqual(hudPresenter.shownPresentations, [.success])
        XCTAssertFalse(appState.isCapturing)
    }

    func testUpdatesMessageWithUnderlyingErrorReasonWhenOCRFails() async {
        let appState = AppState()
        let permissionService = StubPermissionService(
            snapshot: PermissionSnapshot(
                screenRecording: PermissionStatus(
                    title: "屏幕录制",
                    detail: "允许读取截图",
                    isGranted: true
                ),
                accessibility: PermissionStatus(
                    title: "辅助功能",
                    detail: "允许快捷键",
                    isGranted: true,
                    isRequired: false
                )
            )
        )
        let screenCaptureService = StubScreenCaptureService(result: .captured(URL(fileURLWithPath: "/tmp/capture.png")))
        let hudPresenter = StubStatusHUDPresenter()
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(error: OCRServiceError.recognitionFailed("图像无法读取")),
            clipboardService: StubClipboardService(),
            temporaryFileCleaner: StubTemporaryFileCleaner(),
            statusHUDPresenter: hudPresenter
        )

        await coordinator.captureOnce()

        XCTAssertEqual(appState.lastMessage, "OCR 识别失败：图像无法读取")
        XCTAssertEqual(hudPresenter.shownPresentations, [.failure])
        XCTAssertFalse(appState.isCapturing)
    }

    func testShowsFailureHUDWhenClipboardWriteFails() async {
        let appState = AppState()
        let permissionService = StubPermissionService(
            snapshot: PermissionSnapshot(
                screenRecording: PermissionStatus(
                    title: "屏幕录制",
                    detail: "允许读取截图",
                    isGranted: true
                ),
                accessibility: PermissionStatus(
                    title: "辅助功能",
                    detail: "允许快捷键",
                    isGranted: true,
                    isRequired: false
                )
            )
        )
        let screenCaptureService = StubScreenCaptureService(result: .captured(URL(fileURLWithPath: "/tmp/capture.png")))
        let hudPresenter = StubStatusHUDPresenter()
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(text: "hello"),
            clipboardService: StubClipboardService(error: ClipboardServiceError.writeFailed),
            temporaryFileCleaner: StubTemporaryFileCleaner(),
            statusHUDPresenter: hudPresenter
        )

        await coordinator.captureOnce()

        XCTAssertEqual(appState.lastMessage, "写入剪贴板失败")
        XCTAssertEqual(hudPresenter.shownPresentations, [.failure])
        XCTAssertFalse(appState.isCapturing)
    }

    func testShowsFailureHUDWhenCaptureCommandFails() async {
        let appState = AppState()
        let permissionService = StubPermissionService(
            snapshot: PermissionSnapshot(
                screenRecording: PermissionStatus(
                    title: "屏幕录制",
                    detail: "允许读取截图",
                    isGranted: true
                ),
                accessibility: PermissionStatus(
                    title: "辅助功能",
                    detail: "允许快捷键",
                    isGranted: true,
                    isRequired: false
                )
            )
        )
        let screenCaptureService = StubScreenCaptureService(error: ScreenCaptureError.outputUnreadable)
        let hudPresenter = StubStatusHUDPresenter()
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(text: "hello"),
            clipboardService: StubClipboardService(),
            temporaryFileCleaner: StubTemporaryFileCleaner(),
            statusHUDPresenter: hudPresenter
        )

        await coordinator.captureOnce()

        XCTAssertEqual(appState.lastMessage, "截图文件无法读取")
        XCTAssertEqual(hudPresenter.shownPresentations, [.failure])
        XCTAssertFalse(appState.isCapturing)
    }

    func testShowsNoTextHUDWhenOCRFindsNoText() async {
        let appState = AppState()
        let permissionService = StubPermissionService(
            snapshot: PermissionSnapshot(
                screenRecording: PermissionStatus(
                    title: "屏幕录制",
                    detail: "允许读取截图",
                    isGranted: true
                ),
                accessibility: PermissionStatus(
                    title: "辅助功能",
                    detail: "允许快捷键",
                    isGranted: true,
                    isRequired: false
                )
            )
        )
        let screenCaptureService = StubScreenCaptureService(result: .captured(URL(fileURLWithPath: "/tmp/capture.png")))
        let hudPresenter = StubStatusHUDPresenter()
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(error: OCRServiceError.noTextRecognized),
            clipboardService: StubClipboardService(),
            temporaryFileCleaner: StubTemporaryFileCleaner(),
            statusHUDPresenter: hudPresenter
        )

        await coordinator.captureOnce()

        XCTAssertEqual(appState.lastMessage, "未识别到文本")
        XCTAssertEqual(hudPresenter.shownPresentations, [.noText])
        XCTAssertFalse(appState.isCapturing)
    }

    func testDoesNotShowRecognitionHUDDuringScreenSelection() async {
        let appState = AppState()
        let permissionService = StubPermissionService(
            snapshot: PermissionSnapshot(
                screenRecording: PermissionStatus(
                    title: "屏幕录制",
                    detail: "允许读取截图",
                    isGranted: true
                ),
                accessibility: PermissionStatus(
                    title: "辅助功能",
                    detail: "允许快捷键",
                    isGranted: true,
                    isRequired: false
                )
            )
        )
        let hudPresenter = StubStatusHUDPresenter()
        let screenCaptureService = StubScreenCaptureService(result: .captured(URL(fileURLWithPath: "/tmp/capture.png"))) {
            XCTAssertEqual(hudPresenter.events, [.hide])
        }
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(text: "hello"),
            clipboardService: StubClipboardService(lineCount: 1),
            temporaryFileCleaner: StubTemporaryFileCleaner(),
            statusHUDPresenter: hudPresenter
        )

        await coordinator.captureOnce()
    }

    func testCaptureOnceDoesNotStartWhenAlreadyCapturing() async {
        let appState = AppState()
        appState.isCapturing = true
        let permissionService = StubPermissionService(
            snapshot: PermissionSnapshot(
                screenRecording: PermissionStatus(
                    title: "屏幕录制",
                    detail: "允许读取截图",
                    isGranted: true
                ),
                accessibility: PermissionStatus(
                    title: "辅助功能",
                    detail: "允许快捷键",
                    isGranted: true,
                    isRequired: false
                )
            )
        )
        let screenCaptureService = StubScreenCaptureService(result: .captured(URL(fileURLWithPath: "/tmp/capture.png")))
        let hudPresenter = StubStatusHUDPresenter()
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(text: "hello"),
            clipboardService: StubClipboardService(lineCount: 1),
            temporaryFileCleaner: StubTemporaryFileCleaner(),
            statusHUDPresenter: hudPresenter
        )

        await coordinator.captureOnce()

        XCTAssertFalse(screenCaptureService.didCapture)
        XCTAssertTrue(hudPresenter.events.isEmpty)
        XCTAssertTrue(appState.isCapturing)
    }

    func testStartCaptureIgnoresRepeatedTriggersWhileCaptureIsRunning() async throws {
        let appState = AppState()
        let permissionService = StubPermissionService(
            snapshot: PermissionSnapshot(
                screenRecording: PermissionStatus(
                    title: "屏幕录制",
                    detail: "允许读取截图",
                    isGranted: true
                ),
                accessibility: PermissionStatus(
                    title: "辅助功能",
                    detail: "允许快捷键",
                    isGranted: true,
                    isRequired: false
                )
            )
        )
        let screenCaptureService = DelayedScreenCaptureService(result: .cancelled)
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(text: "hello"),
            clipboardService: StubClipboardService(lineCount: 1),
            temporaryFileCleaner: StubTemporaryFileCleaner(),
            statusHUDPresenter: StubStatusHUDPresenter()
        )

        coordinator.startCapture()
        try await Task.sleep(nanoseconds: 20_000_000)
        coordinator.startCapture()
        try await Task.sleep(nanoseconds: 180_000_000)

        XCTAssertEqual(screenCaptureService.captureCount, 1)
        XCTAssertFalse(appState.isCapturing)
    }
}

@MainActor
private final class StubPermissionService: PermissionServicing {
    private let snapshot: PermissionSnapshot
    private(set) var didOpenScreenRecordingSettings = false
    private(set) var didOpenAccessibilitySettings = false

    init(snapshot: PermissionSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> PermissionSnapshot {
        snapshot
    }

    func openScreenRecordingSettings() {
        didOpenScreenRecordingSettings = true
    }

    func openAccessibilitySettings() {
        didOpenAccessibilitySettings = true
    }
}

private final class StubScreenCaptureService: ScreenCapturing {
    private let outcome: Result<ScreenCaptureResult, Error>
    private let onCapture: (() -> Void)?
    private(set) var didCapture = false

    init(result: ScreenCaptureResult = .cancelled, onCapture: (() -> Void)? = nil) {
        self.outcome = .success(result)
        self.onCapture = onCapture
    }

    init(error: Error, onCapture: (() -> Void)? = nil) {
        self.outcome = .failure(error)
        self.onCapture = onCapture
    }

    func captureSelection(to outputURL: URL) async throws -> ScreenCaptureResult {
        didCapture = true
        onCapture?()
        return try outcome.get()
    }
}

private final class DelayedScreenCaptureService: ScreenCapturing {
    private let result: ScreenCaptureResult
    private let lock = NSLock()
    private var capturedCount = 0

    init(result: ScreenCaptureResult) {
        self.result = result
    }

    var captureCount: Int {
        lock.withLock {
            capturedCount
        }
    }

    func captureSelection(to outputURL: URL) async throws -> ScreenCaptureResult {
        lock.withLock {
            capturedCount += 1
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        return result
    }
}

private final class StubOCRService: TextRecognizing {
    private let result: Result<String, Error>

    init(text: String = "") {
        self.result = .success(text)
    }

    init(error: Error) {
        self.result = .failure(error)
    }

    func recognizeText(in imageURL: URL) async throws -> String {
        try result.get()
    }
}

@MainActor
private final class StubClipboardService: ClipboardWriting {
    private let lineCount: Int
    private let error: Error?

    init(lineCount: Int = 0, error: Error? = nil) {
        self.lineCount = lineCount
        self.error = error
    }

    func write(_ text: String) throws -> Int {
        if let error {
            throw error
        }

        return lineCount
    }
}

@MainActor
private final class StubStatusHUDPresenter: StatusHUDPresenting {
    enum Event: Equatable {
        case show(StatusHUDPresentation)
        case hide
    }

    private(set) var events: [Event] = []

    var shownPresentations: [StatusHUDPresentation] {
        events.compactMap { event in
            guard case .show(let presentation) = event else {
                return nil
            }

            return presentation
        }
    }

    func show(_ presentation: StatusHUDPresentation) {
        events.append(.show(presentation))
    }

    func hide() {
        events.append(.hide)
    }
}

private struct StubTemporaryFileCleaner: TemporaryFileCleaning {
    func createTemporaryScreenshotURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipSight-test-\(UUID().uuidString).png")
    }

    func remove(_ url: URL) throws {}
}

private func temporaryDefaults() -> UserDefaults {
    let suiteName = "ClipSight.CaptureOCRCoordinatorPermissionTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
