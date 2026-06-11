import AppKit
import Foundation

@MainActor
public final class ClipboardService: ClipboardWriting {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    @discardableResult
    public func write(_ text: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ClipboardServiceError.emptyText
        }

        pasteboard.clearContents()
        guard pasteboard.setString(trimmed, forType: .string) else {
            throw ClipboardServiceError.writeFailed
        }

        return trimmed
            .split(whereSeparator: \.isNewline)
            .count
    }
}
