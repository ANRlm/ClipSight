import Foundation
import XCTest
@testable import ClipSightCore

final class TemporaryFileCleanerTests: XCTestCase {
    func testCreateTemporaryScreenshotURLUsesPNGExtension() {
        let cleaner = TemporaryFileCleaner(fileManager: .default)

        let url = cleaner.createTemporaryScreenshotURL()

        XCTAssertEqual(url.pathExtension, "png")
        XCTAssertTrue(url.lastPathComponent.hasPrefix("ClipSight-"))
    }

    func testRemoveDeletesExistingFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipSightCleanerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let fileURL = directory.appendingPathComponent("capture.png")
        try Data("temporary".utf8).write(to: fileURL)

        let cleaner = TemporaryFileCleaner(fileManager: .default)
        try cleaner.remove(fileURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testRemoveIgnoresMissingFile() throws {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipSight-missing-\(UUID().uuidString).png")
        let cleaner = TemporaryFileCleaner(fileManager: .default)

        try cleaner.remove(missingURL)
    }
}
