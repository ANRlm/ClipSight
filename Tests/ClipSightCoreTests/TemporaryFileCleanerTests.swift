import Foundation
import Testing
@testable import ClipSightCore

struct TemporaryFileCleanerTests {
    @Test
    func createTemporaryScreenshotURLUsesPNGExtension() {
        let cleaner = TemporaryFileCleaner(fileManager: .default)

        let url = cleaner.createTemporaryScreenshotURL()

        #expect(url.pathExtension == "png")
        #expect(url.lastPathComponent.hasPrefix("ClipSight-"))
    }

    @Test
    func removeDeletesExistingFile() throws {
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

        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test
    func removeIgnoresMissingFile() throws {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipSight-missing-\(UUID().uuidString).png")
        let cleaner = TemporaryFileCleaner(fileManager: .default)

        try cleaner.remove(missingURL)
    }
}
