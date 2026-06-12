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
        switch self {
        case .launchFailed(let message):
            "无法启动系统截图工具：\(message)"
        case .commandFailed(let status, let message):
            message.isEmpty ? "系统截图失败，退出码 \(status)" : "系统截图失败：\(message)"
        case .outputUnreadable:
            "截图文件无法读取"
        }
    }
}

public enum OCRServiceError: LocalizedError, Equatable {
    case noTextRecognized
    case recognitionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noTextRecognized:
            "未识别到文本"
        case .recognitionFailed(let message):
            "OCR 识别失败：\(message)"
        }
    }
}

public enum ClipboardServiceError: LocalizedError, Equatable {
    case emptyText
    case writeFailed

    public var errorDescription: String? {
        switch self {
        case .emptyText:
            "没有可复制的文本"
        case .writeFailed:
            "写入剪贴板失败"
        }
    }
}
