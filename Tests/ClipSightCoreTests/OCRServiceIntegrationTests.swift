import AppKit
import Foundation
import Testing
@testable import ClipSightCore

private let shouldRunOCRIntegrationTests = ProcessInfo.processInfo.environment["CLIPSIGHT_RUN_OCR_INTEGRATION"] == "1"

@MainActor
struct OCRServiceIntegrationTests {
    @Test(.enabled(if: shouldRunOCRIntegrationTests))
    func recognizesGeneratedChineseAndEnglishImage() async throws {
        let imageURL = try makeOCRFixtureImage()
        defer {
            try? FileManager.default.removeItem(at: imageURL)
        }

        let text = try await OCRService().recognizeText(in: imageURL)

        #expect(text.localizedCaseInsensitiveContains("CLIPSIGHT"))
        #expect(text.contains("中文"))
        #expect(text.contains("识别"))
    }

    private func makeOCRFixtureImage() throws -> URL {
        let size = NSSize(width: 1000, height: 360)
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw OCRFixtureError.imageEncodingFailed
        }

        let context = NSGraphicsContext(bitmapImageRep: representation)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 54, weight: .semibold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph
        ]

        ("CLIPSIGHT OCR TEST" as NSString).draw(
            at: NSPoint(x: 64, y: 220),
            withAttributes: attributes
        )
        ("中文识别测试" as NSString).draw(
            at: NSPoint(x: 64, y: 96),
            withAttributes: attributes
        )

        guard let pngData = representation.representation(using: .png, properties: [:]) else {
            throw OCRFixtureError.imageEncodingFailed
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipSight-OCRIntegration-\(UUID().uuidString)")
            .appendingPathExtension("png")
        try pngData.write(to: url)
        return url
    }
}

private enum OCRFixtureError: Error {
    case imageEncodingFailed
}
