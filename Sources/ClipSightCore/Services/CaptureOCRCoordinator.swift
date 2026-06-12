import Foundation
import os

@MainActor
public final class CaptureOCRCoordinator {
    private let appState: AppState
    private let permissionService: any PermissionServicing
    private let screenCaptureService: any ScreenCapturing
    private let ocrService: any TextRecognizing
    private let clipboardService: any ClipboardWriting
    private let temporaryFileCleaner: any TemporaryFileCleaning
    private let statusHUDPresenter: (any StatusHUDPresenting)?
    private let logger = Logger(subsystem: ClipSightLogging.subsystem, category: "CaptureOCR")

    public init(
        appState: AppState,
        permissionService: any PermissionServicing,
        screenCaptureService: any ScreenCapturing,
        ocrService: any TextRecognizing,
        clipboardService: any ClipboardWriting,
        temporaryFileCleaner: any TemporaryFileCleaning,
        statusHUDPresenter: (any StatusHUDPresenting)? = nil
    ) {
        self.appState = appState
        self.permissionService = permissionService
        self.screenCaptureService = screenCaptureService
        self.ocrService = ocrService
        self.clipboardService = clipboardService
        self.temporaryFileCleaner = temporaryFileCleaner
        self.statusHUDPresenter = statusHUDPresenter
    }

    public func startCapture() {
        guard !appState.isCapturing else {
            logger.debug("Ignoring capture trigger because another capture is already running")
            return
        }

        appState.isCapturing = true
        Task {
            await performCapture()
        }
    }

    public func captureOnce() async {
        guard !appState.isCapturing else {
            logger.debug("Ignoring direct capture request because another capture is already running")
            return
        }

        appState.isCapturing = true
        await performCapture()
    }

    private func performCapture() async {
        appState.lastMessage = "正在截图识别"
        statusHUDPresenter?.hide()
        logger.info("Capture OCR started")

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
            logger.info("Screen recording permission missing; opened System Settings")
            finishWithMessage("需要屏幕录制权限，已打开系统设置")
            return
        }

        do {
            let captureResult = try await screenCaptureService.captureSelection(to: temporaryURL)

            guard case .captured(let imageURL) = captureResult else {
                logger.info("Capture OCR cancelled by user")
                appState.lastMessage = "已取消截图"
                return
            }

            let text = try await ocrService.recognizeText(in: imageURL)
            let lineCount = try clipboardService.write(text)
            let message = "已复制 \(lineCount) 行文本"
            statusHUDPresenter?.show(.success)
            logger.info("Capture OCR succeeded with \(lineCount, privacy: .public) recognized lines copied")
            finishWithMessage(message)
        } catch OCRServiceError.noTextRecognized {
            statusHUDPresenter?.show(.noText)
            logger.info("Capture OCR completed with no recognized text")
            finishWithMessage("未识别到文本")
        } catch {
            let message = error.localizedDescription
            statusHUDPresenter?.show(.failure)
            logger.error("Capture OCR failed: \(message, privacy: .public)")
            finishWithMessage(message)
        }
    }

    private func finishWithMessage(_ message: String) {
        appState.lastMessage = message
    }
}
