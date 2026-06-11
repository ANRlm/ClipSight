import Foundation
import Testing
@testable import ClipSightCore

@MainActor
struct CaptureOCRCoordinatorPermissionTests {
    @Test
    func opensScreenRecordingSettingsWhenScreenRecordingPermissionIsMissing() async {
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
        let statusPresenter = StubStatusHUDPresenter()
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(),
            clipboardService: StubClipboardService(),
            statusPresenter: statusPresenter,
            temporaryFileCleaner: StubTemporaryFileCleaner()
        )

        await coordinator.captureOnce()

        #expect(permissionService.didOpenScreenRecordingSettings)
        #expect(!permissionService.didOpenAccessibilitySettings)
        #expect(!screenCaptureService.didCapture)
        #expect(appState.lastMessage == "需要屏幕录制权限，已打开系统设置")
        #expect(statusPresenter.lastPresentation == .failure("需要屏幕录制权限"))
    }

    @Test
    func continuesCaptureWhenOnlyAccessibilityPermissionIsMissing() async {
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
        let statusPresenter = StubStatusHUDPresenter()
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(),
            clipboardService: StubClipboardService(),
            statusPresenter: statusPresenter,
            temporaryFileCleaner: StubTemporaryFileCleaner()
        )

        await coordinator.captureOnce()

        #expect(!permissionService.didOpenScreenRecordingSettings)
        #expect(!permissionService.didOpenAccessibilitySettings)
        #expect(screenCaptureService.didCapture)
        #expect(appState.lastMessage == "已取消截图")
        #expect(statusPresenter.lastPresentation == nil)
    }

    @Test
    func presentsSuccessHUDWhenTextIsCopied() async {
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
        let statusPresenter = StubStatusHUDPresenter()
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(text: "hello\nworld"),
            clipboardService: StubClipboardService(lineCount: 2),
            statusPresenter: statusPresenter,
            temporaryFileCleaner: StubTemporaryFileCleaner()
        )

        await coordinator.captureOnce()

        #expect(appState.lastMessage == "已复制 2 行文本")
        #expect(statusPresenter.lastPresentation == .success("已复制到剪贴板"))
    }

    @Test
    func presentsFailureHUDWithUnderlyingErrorReasonWhenOCRFails() async {
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
        let statusPresenter = StubStatusHUDPresenter()
        let coordinator = CaptureOCRCoordinator(
            appState: appState,
            permissionService: permissionService,
            screenCaptureService: screenCaptureService,
            ocrService: StubOCRService(error: OCRServiceError.recognitionFailed("图像无法读取")),
            clipboardService: StubClipboardService(),
            statusPresenter: statusPresenter,
            temporaryFileCleaner: StubTemporaryFileCleaner()
        )

        await coordinator.captureOnce()

        #expect(appState.lastMessage == "OCR 识别失败：图像无法读取")
        #expect(statusPresenter.lastPresentation == .failure("OCR 识别失败：图像无法读取"))
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
    private let result: ScreenCaptureResult
    private(set) var didCapture = false

    init(result: ScreenCaptureResult = .cancelled) {
        self.result = result
    }

    func captureSelection(to outputURL: URL) async throws -> ScreenCaptureResult {
        didCapture = true
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

    init(lineCount: Int = 0) {
        self.lineCount = lineCount
    }

    func write(_ text: String) throws -> Int {
        lineCount
    }
}

@MainActor
private final class StubStatusHUDPresenter: StatusHUDPresenting {
    private(set) var lastPresentation: StatusHUDPresentation?

    func show(_ presentation: StatusHUDPresentation) {
        lastPresentation = presentation
    }
}

private struct StubTemporaryFileCleaner: TemporaryFileCleaning {
    func createTemporaryScreenshotURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipSight-test-\(UUID().uuidString).png")
    }

    func remove(_ url: URL) throws {}
}
