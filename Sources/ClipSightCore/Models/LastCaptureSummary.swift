import Foundation

public struct LastCaptureSummary: Equatable, Sendable {
    public enum Result: String, Equatable, Sendable {
        case success
        case noText
        case failure
        case cancelled
        case permissionMissing
    }

    public let result: Result
    public let occurredAt: Date
    public let durationMilliseconds: Int
    public let recognizedLineCount: Int?
    public let errorCategory: String?

    public init(
        result: Result,
        occurredAt: Date = Date(),
        durationMilliseconds: Int,
        recognizedLineCount: Int? = nil,
        errorCategory: String? = nil
    ) {
        self.result = result
        self.occurredAt = occurredAt
        self.durationMilliseconds = max(0, durationMilliseconds)
        self.recognizedLineCount = recognizedLineCount
        self.errorCategory = errorCategory
    }

    public var diagnosticLabel: String {
        var parts = [
            "result=\(result.rawValue)",
            "duration_ms=\(durationMilliseconds)"
        ]

        if let recognizedLineCount {
            parts.append("lines=\(recognizedLineCount)")
        }

        if let errorCategory, !errorCategory.isEmpty {
            parts.append("error=\(errorCategory)")
        }

        return parts.joined(separator: " ")
    }
}
