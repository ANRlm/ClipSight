import AppKit
import Foundation
import OSLog

@MainActor
public final class ClipboardService: ClipboardWriting {
    private let logger = Logger(subsystem: ClipSightLogging.subsystem, category: ClipSightLogging.Category.clipboard)
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    @discardableResult
    public func write(_ text: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger.error("Clipboard write rejected because text was empty")
            throw ClipboardServiceError.emptyText
        }

        pasteboard.clearContents()
        guard pasteboard.setString(trimmed, forType: .string) else {
            logger.error("Clipboard write failed")
            throw ClipboardServiceError.writeFailed
        }

        let lineCount = trimmed
            .split(whereSeparator: \.isNewline)
            .count
        logger.info("Clipboard write succeeded lines=\(lineCount, privacy: .public)")
        return lineCount
    }
}
