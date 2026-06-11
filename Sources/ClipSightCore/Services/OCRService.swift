import Foundation
import Vision

public final class OCRService: TextRecognizing {
    public init() {}

    public func recognizeText(in imageURL: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(url: imageURL, options: [:])

            do {
                try handler.perform([request])
            } catch {
                throw OCRServiceError.recognitionFailed(error.localizedDescription)
            }

            let lines = (request.results ?? []).compactMap { observation -> OCRTextLine? in
                guard let candidate = observation.topCandidates(1).first else {
                    return nil
                }

                return OCRTextLine(text: candidate.string, boundingBox: observation.boundingBox)
            }

            let text = OCRTextFormatter.formattedText(from: lines)
            guard !text.isEmpty else {
                throw OCRServiceError.noTextRecognized
            }

            return text
        }.value
    }
}
