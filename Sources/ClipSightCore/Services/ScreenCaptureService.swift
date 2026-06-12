import Foundation

public final class ScreenCaptureService: ScreenCapturing {
    private let executablePath: String
    private let fileManager: FileManager

    public init(
        executablePath: String = "/usr/sbin/screencapture",
        fileManager: FileManager = .default
    ) {
        self.executablePath = executablePath
        self.fileManager = fileManager
    }

    public func captureSelection(to outputURL: URL) async throws -> ScreenCaptureResult {
        let executablePath = executablePath
        let fileManager = fileManager

        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = ["-i", outputURL.path]

            let errorPipe = Pipe()
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                throw ScreenCaptureError.launchFailed(error.localizedDescription)
            }

            process.waitUntilExit()

            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard fileManager.fileExists(atPath: outputURL.path) else {
                return .cancelled
            }

            let attributes = try fileManager.attributesOfItem(atPath: outputURL.path)
            let fileSize = attributes[.size] as? NSNumber
            guard (fileSize?.intValue ?? 0) > 0 else {
                return .cancelled
            }

            guard process.terminationStatus == 0 else {
                throw ScreenCaptureError.commandFailed(
                    status: process.terminationStatus,
                    message: errorMessage
                )
            }

            return .captured(outputURL)
        }.value
    }
}
