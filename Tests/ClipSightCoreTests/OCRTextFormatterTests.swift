import CoreGraphics
import Testing
@testable import ClipSightCore

struct OCRTextFormatterTests {
    @Test
    func formatsLinesInTopToBottomThenLeftToRightOrder() {
        let lines = [
            OCRTextLine(text: "bottom right", boundingBox: CGRect(x: 0.7, y: 0.1, width: 0.2, height: 0.1)),
            OCRTextLine(text: "top right", boundingBox: CGRect(x: 0.6, y: 0.8, width: 0.3, height: 0.1)),
            OCRTextLine(text: "top left", boundingBox: CGRect(x: 0.1, y: 0.81, width: 0.3, height: 0.1)),
            OCRTextLine(text: "bottom left", boundingBox: CGRect(x: 0.1, y: 0.11, width: 0.2, height: 0.1))
        ]

        let text = OCRTextFormatter.formattedText(from: lines)

        #expect(text == "top left\ntop right\nbottom left\nbottom right")
    }

    @Test
    func dropsBlankLinesAndTrimsWhitespace() {
        let lines = [
            OCRTextLine(text: "  第一行  ", boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.5, height: 0.1)),
            OCRTextLine(text: "   ", boundingBox: CGRect(x: 0.1, y: 0.6, width: 0.5, height: 0.1)),
            OCRTextLine(text: "\nSecond line\t", boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.5, height: 0.1))
        ]

        let text = OCRTextFormatter.formattedText(from: lines)

        #expect(text == "第一行\nSecond line")
    }
}
