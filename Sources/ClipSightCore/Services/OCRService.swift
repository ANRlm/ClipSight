import Foundation
import OSLog
import Vision

public final class OCRService: TextRecognizing {
    private static let logger = Logger(subsystem: ClipSightLogging.subsystem, category: ClipSightLogging.Category.ocr)

    public init() {}

    public func recognizeText(in imageURL: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let startedAt = Date()
            let recognitionLanguages = ["zh-Hans", "en-US"]
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = recognitionLanguages
            request.usesLanguageCorrection = true
            Self.logger.info("OCR request started languages=\(recognitionLanguages.joined(separator: ","), privacy: .public)")

            let handler = VNImageRequestHandler(url: imageURL, options: [:])

            do {
                try handler.perform([request])
            } catch {
                let elapsedMilliseconds = Int(Date().timeIntervalSince(startedAt) * 1_000)
                let errorType = String(describing: type(of: error))
                Self.logger.error("OCR request failed elapsed_ms=\(elapsedMilliseconds, privacy: .public) error_type=\(errorType, privacy: .public)")
                throw OCRServiceError.recognitionFailed(error.localizedDescription)
            }

            let observations = request.results ?? []
            let lines = observations.compactMap { observation -> OCRTextLine? in
                guard let candidate = observation.topCandidates(1).first else {
                    return nil
                }

                return OCRTextLine(text: candidate.string, boundingBox: observation.boundingBox)
            }

            let text = OCRTextFormatter.formattedText(from: lines)
            let elapsedMilliseconds = Int(Date().timeIntervalSince(startedAt) * 1_000)
            guard !text.isEmpty else {
                Self.logger.error("OCR completed without text elapsed_ms=\(elapsedMilliseconds, privacy: .public) observations=\(observations.count, privacy: .public) lines=\(lines.count, privacy: .public)")
                throw OCRServiceError.noTextRecognized
            }

            Self.logger.info("OCR completed elapsed_ms=\(elapsedMilliseconds, privacy: .public) observations=\(observations.count, privacy: .public) lines=\(lines.count, privacy: .public)")
            return text
        }.value
    }
}
