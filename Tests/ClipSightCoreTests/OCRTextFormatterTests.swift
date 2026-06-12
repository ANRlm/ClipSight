import CoreGraphics
import XCTest
@testable import ClipSightCore

final class OCRTextFormatterTests: XCTestCase {
    func testFormatsLinesInTopToBottomThenLeftToRightOrder() {
        let lines = [
            OCRTextLine(text: "bottom right", boundingBox: CGRect(x: 0.7, y: 0.1, width: 0.2, height: 0.1)),
            OCRTextLine(text: "top right", boundingBox: CGRect(x: 0.6, y: 0.8, width: 0.3, height: 0.1)),
            OCRTextLine(text: "top left", boundingBox: CGRect(x: 0.1, y: 0.81, width: 0.3, height: 0.1)),
            OCRTextLine(text: "bottom left", boundingBox: CGRect(x: 0.1, y: 0.11, width: 0.2, height: 0.1))
        ]

        let text = OCRTextFormatter.formattedText(from: lines)

        XCTAssertEqual(text, "top left\ntop right\nbottom left\nbottom right")
    }

    func testDropsBlankLinesAndTrimsWhitespace() {
        let lines = [
            OCRTextLine(text: "  第一行  ", boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.5, height: 0.1)),
            OCRTextLine(text: "   ", boundingBox: CGRect(x: 0.1, y: 0.6, width: 0.5, height: 0.1)),
            OCRTextLine(text: "\nSecond line\t", boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.5, height: 0.1))
        ]

        let text = OCRTextFormatter.formattedText(from: lines)

        XCTAssertEqual(text, "第一行\nSecond line")
    }

    func testKeepsSlightVerticalJitterInSameRowOrderedLeftToRight() {
        let lines = [
            line("right", x: 0.62, top: 0.892),
            line("left", x: 0.10, top: 0.905),
            line("middle", x: 0.36, top: 0.883)
        ]

        let text = OCRTextFormatter.formattedText(from: lines)

        XCTAssertEqual(text, "left\nmiddle\nright")
    }

    func testOrdersRowsBeforeHorizontalPositionAcrossLines() {
        let lines = [
            line("bottom left", x: 0.10, top: 0.41),
            line("top right", x: 0.72, top: 0.90),
            line("middle left", x: 0.06, top: 0.66)
        ]

        let text = OCRTextFormatter.formattedText(from: lines)

        XCTAssertEqual(text, "top right\nmiddle left\nbottom left")
    }

    func testFormatsMixedChineseAndEnglishTextWithoutDroppingContent() {
        let lines = [
            line("  OCR Ready  ", x: 0.08, top: 0.72),
            line("中文 Mixed 123", x: 0.08, top: 0.56)
        ]

        let text = OCRTextFormatter.formattedText(from: lines)

        XCTAssertEqual(text, "OCR Ready\n中文 Mixed 123")
    }

    func testFormatsTwoColumnTableStyleTextInRowMajorOrder() {
        let lines = [
            line("R2C2", x: 0.58, top: 0.68),
            line("R1C2", x: 0.58, top: 0.91),
            line("R2C1", x: 0.08, top: 0.675),
            line("R1C1", x: 0.08, top: 0.895)
        ]

        let text = OCRTextFormatter.formattedText(from: lines)

        XCTAssertEqual(text, "R1C1\nR1C2\nR2C1\nR2C2")
    }

    func testKeepsWiderVisualRowJitterTogetherForCodeFragments() {
        let lines = [
            line("return", x: 0.18, top: 0.72),
            line("total", x: 0.35, top: 0.684),
            line("let", x: 0.12, top: 0.91),
            line("total", x: 0.24, top: 0.876),
            line("=", x: 0.43, top: 0.884),
            line("price + tax", x: 0.52, top: 0.868)
        ]

        let text = OCRTextFormatter.formattedText(from: lines)

        XCTAssertEqual(text, "let\ntotal\n=\nprice + tax\nreturn\ntotal")
    }

    func testFormatsInvoiceLikeMixedLanguageRows() {
        let lines = [
            line("金额", x: 0.08, top: 0.81),
            line("Amount", x: 0.34, top: 0.788),
            line("$128.00", x: 0.70, top: 0.795),
            line("税费", x: 0.08, top: 0.64),
            line("Tax", x: 0.34, top: 0.615),
            line("$8.00", x: 0.70, top: 0.622)
        ]

        let text = OCRTextFormatter.formattedText(from: lines)

        XCTAssertEqual(text, "金额\nAmount\n$128.00\n税费\nTax\n$8.00")
    }

    private func line(_ text: String, x: CGFloat, top: CGFloat) -> OCRTextLine {
        OCRTextLine(
            text: text,
            boundingBox: CGRect(x: x, y: top - 0.05, width: 0.22, height: 0.05)
        )
    }
}
