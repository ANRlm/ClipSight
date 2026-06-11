import Foundation

@MainActor
public protocol PermissionServicing: AnyObject {
    func currentSnapshot() -> PermissionSnapshot
    func openScreenRecordingSettings()
    func openAccessibilitySettings()
}

public protocol ScreenCapturing: AnyObject {
    func captureSelection(to outputURL: URL) async throws -> ScreenCaptureResult
}

public protocol TextRecognizing: AnyObject {
    func recognizeText(in imageURL: URL) async throws -> String
}

@MainActor
public protocol ClipboardWriting: AnyObject {
    @discardableResult
    func write(_ text: String) throws -> Int
}

@MainActor
public protocol StatusHUDPresenting: AnyObject {
    func show(_ presentation: StatusHUDPresentation)
}

public protocol TemporaryFileCleaning {
    func createTemporaryScreenshotURL() -> URL
    func remove(_ url: URL) throws
}
