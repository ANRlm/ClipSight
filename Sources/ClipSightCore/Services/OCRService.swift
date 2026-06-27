import Foundation
import ImageIO
import OSLog
import Vision

public final class OCRService: TextRecognizing {
    private static let logger = Logger(subsystem: ClipSightLogging.subsystem, category: ClipSightLogging.Category.ocr)
    private static let minimumRecognizableDimension = 3

    public init() {}

    public func recognizeText(in imageURL: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let startedAt = Date()
            let recognitionLanguages = ["zh-Hans", "en-US"]

            if let imageSize = Self.imagePixelSize(for: imageURL),
               imageSize.width < Self.minimumRecognizableDimension || imageSize.height < Self.minimumRecognizableDimension {
                Self.logger.info("OCR skipped tiny image width=\(imageSize.width, privacy: .public) height=\(imageSize.height, privacy: .public)")
                throw OCRServiceError.noTextRecognized
            }

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
                Self.logger.error("OCR request failed elapsed_ms=\(elapsedMilliseconds, privacy: .public) error_type=\(errorType, privacy: .public) message=\(error.localizedDescription, privacy: .public)")
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

    private static func imagePixelSize(for imageURL: URL) -> (width: Int, height: Int)? {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return nil
        }

        return (width.intValue, height.intValue)
    }
}
