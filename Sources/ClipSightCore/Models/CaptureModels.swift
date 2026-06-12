import Foundation

public enum ScreenCaptureResult: Equatable {
    case captured(URL)
    case cancelled
}

public enum ScreenCaptureError: LocalizedError {
    case launchFailed(String)
    case commandFailed(status: Int32, message: String)
    case outputUnreadable

    public var errorDescription: String? {
        AppStrings(language: .chinese).screenCaptureErrorMessage(self)
    }
}

public enum OCRServiceError: LocalizedError, Equatable {
    case noTextRecognized
    case recognitionFailed(String)

    public var errorDescription: String? {
        AppStrings(language: .chinese).ocrErrorMessage(self)
    }
}

public enum ClipboardServiceError: LocalizedError, Equatable {
    case emptyText
    case writeFailed

    public var errorDescription: String? {
        AppStrings(language: .chinese).clipboardErrorMessage(self)
    }
}
