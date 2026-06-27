import AppKit
import Foundation
import XCTest
@testable import ClipSightCore

@MainActor
final class OCRServiceIntegrationTests: XCTestCase {
    func testTinyImageIsTreatedAsNoRecognizedText() async throws {
        let imageURL = try makeTinyImage()
        defer {
            try? FileManager.default.removeItem(at: imageURL)
        }

        do {
            _ = try await OCRService().recognizeText(in: imageURL)
            XCTFail("Expected tiny images to be treated as no recognized text.")
        } catch OCRServiceError.noTextRecognized {
        } catch {
            XCTFail("Expected OCRServiceError.noTextRecognized, got \(error).")
        }
    }

    func testRecognizesGeneratedChineseAndEnglishImage() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CLIPSIGHT_RUN_OCR_INTEGRATION"] == "1",
            "Set CLIPSIGHT_RUN_OCR_INTEGRATION=1 to run Vision OCR integration tests."
        )

        let imageURL = try makeOCRFixtureImage()
        defer {
            try? FileManager.default.removeItem(at: imageURL)
        }

        let text = try await OCRService().recognizeText(in: imageURL)

        XCTAssertTrue(text.localizedCaseInsensitiveContains("CLIPSIGHT"))
        XCTAssertTrue(text.contains("中文"))
        XCTAssertTrue(text.contains("识别"))
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

    private func makeTinyImage() throws -> URL {
        let size = NSSize(width: 1, height: 1)
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

        guard let pngData = representation.representation(using: .png, properties: [:]) else {
            throw OCRFixtureError.imageEncodingFailed
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipSight-TinyOCR-\(UUID().uuidString)")
            .appendingPathExtension("png")
        try pngData.write(to: url)
        return url
    }
}

private enum OCRFixtureError: Error {
    case imageEncodingFailed
}
