import Foundation

public struct TemporaryFileCleaner: TemporaryFileCleaning {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func createTemporaryScreenshotURL() -> URL {
        fileManager.temporaryDirectory
            .appendingPathComponent("ClipSight-\(UUID().uuidString)")
            .appendingPathExtension("png")
    }

    public func remove(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }
}
