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
    private let logger = Logger(subsystem: ClipSightLogging.subsystem, category: ClipSightLogging.Category.captureOCR)

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
        let startedAt = Date()
        appState.lastMessage = appState.strings.ocrCapturingMessage
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
            recordCaptureSummary(.permissionMissing, startedAt: startedAt, errorCategory: "ScreenRecordingPermission")
            finishWithMessage(appState.strings.permissionMissingOpenedSettingsMessage)
            return
        }

        do {
            let captureResult = try await screenCaptureService.captureSelection(to: temporaryURL)

            guard case .captured(let imageURL) = captureResult else {
                logger.info("Capture OCR cancelled by user")
                recordCaptureSummary(.cancelled, startedAt: startedAt)
                appState.lastMessage = appState.strings.captureCancelledMessage
                return
            }

            let text = try await ocrService.recognizeText(in: imageURL)
            let lineCount = try clipboardService.write(text)
            let message = appState.strings.copiedLinesMessage(lineCount)
            statusHUDPresenter?.show(.success)
            recordCaptureSummary(.success, startedAt: startedAt, recognizedLineCount: lineCount)
            logger.info("Capture OCR succeeded with \(lineCount, privacy: .public) recognized lines copied")
            finishWithMessage(message)
        } catch OCRServiceError.noTextRecognized {
            statusHUDPresenter?.show(.noText)
            recordCaptureSummary(.noText, startedAt: startedAt)
            logger.info("Capture OCR completed with no recognized text")
            finishWithMessage(appState.strings.noTextRecognizedMessage)
        } catch {
            let message = appState.strings.errorMessage(for: error)
            statusHUDPresenter?.show(.failure)
            recordCaptureSummary(.failure, startedAt: startedAt, errorCategory: errorCategory(for: error))
            logger.error("Capture OCR failed: \(message, privacy: .public)")
            finishWithMessage(message)
        }
    }

    private func recordCaptureSummary(
        _ result: LastCaptureSummary.Result,
        startedAt: Date,
        recognizedLineCount: Int? = nil,
        errorCategory: String? = nil
    ) {
        let elapsedMilliseconds = Int(Date().timeIntervalSince(startedAt) * 1_000)
        appState.lastCaptureSummary = LastCaptureSummary(
            result: result,
            durationMilliseconds: elapsedMilliseconds,
            recognizedLineCount: recognizedLineCount,
            errorCategory: errorCategory
        )
    }

    private func errorCategory(for error: Error) -> String {
        switch error {
        case is ScreenCaptureError:
            return "ScreenCaptureError"
        case is OCRServiceError:
            return "OCRServiceError"
        case is ClipboardServiceError:
            return "ClipboardServiceError"
        default:
            return String(describing: type(of: error))
        }
    }

    private func finishWithMessage(_ message: String) {
        appState.lastMessage = message
    }
}
