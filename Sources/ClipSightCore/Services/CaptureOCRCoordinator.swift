import Foundation
import os

@MainActor
public final class CaptureOCRCoordinator {
    private let appState: AppState
    private let permissionService: any PermissionServicing
    private let screenCaptureService: any ScreenCapturing
    private let ocrService: any TextRecognizing
    private let clipboardService: any ClipboardWriting
    private let statusPresenter: any StatusHUDPresenting
    private let temporaryFileCleaner: any TemporaryFileCleaning
    private let logger = Logger(subsystem: "com.local.ClipSight", category: "CaptureOCR")

    public init(
        appState: AppState,
        permissionService: any PermissionServicing,
        screenCaptureService: any ScreenCapturing,
        ocrService: any TextRecognizing,
        clipboardService: any ClipboardWriting,
        statusPresenter: any StatusHUDPresenting,
        temporaryFileCleaner: any TemporaryFileCleaning
    ) {
        self.appState = appState
        self.permissionService = permissionService
        self.screenCaptureService = screenCaptureService
        self.ocrService = ocrService
        self.clipboardService = clipboardService
        self.statusPresenter = statusPresenter
        self.temporaryFileCleaner = temporaryFileCleaner
    }

    public func startCapture() {
        guard !appState.isCapturing else {
            return
        }

        Task {
            await captureOnce()
        }
    }

    public func captureOnce() async {
        appState.isCapturing = true
        appState.lastMessage = "正在截图识别"

        let temporaryURL = temporaryFileCleaner.createTemporaryScreenshotURL()

        defer {
            appState.isCapturing = false
            do {
                try temporaryFileCleaner.remove(temporaryURL)
            } catch {
                logger.warning("Failed to clean temporary screenshot: \(error.localizedDescription, privacy: .public)")
            }
        }

        let permissions = permissionService.currentSnapshot()
        appState.applyPermissionSnapshot(permissions)

        guard permissions.screenRecording.isGranted else {
            permissionService.openScreenRecordingSettings()
            finishWithMessage(
                "需要屏幕录制权限，已打开系统设置",
                presentation: .failure("需要屏幕录制权限")
            )
            return
        }

        do {
            let captureResult = try await screenCaptureService.captureSelection(to: temporaryURL)

            guard case .captured(let imageURL) = captureResult else {
                appState.lastMessage = "已取消截图"
                return
            }

            let text = try await ocrService.recognizeText(in: imageURL)
            let lineCount = try clipboardService.write(text)
            let message = "已复制 \(lineCount) 行文本"
            finishWithMessage(message, presentation: .success("已复制到剪贴板"))
        } catch OCRServiceError.noTextRecognized {
            finishWithMessage("未识别到文本", presentation: .failure("未识别到文本"))
        } catch {
            finishWithMessage(error.localizedDescription, presentation: .failure("识别失败"))
        }
    }

    private func finishWithMessage(
        _ message: String,
        presentation: StatusHUDPresentation
    ) {
        appState.lastMessage = message
        statusPresenter.show(presentation)
    }
}
