import Foundation

public enum OCRTextFormatter {
    private static let rowTolerance: CGFloat = 0.03

    public static func formattedText(from lines: [OCRTextLine]) -> String {
        lines
            .map { line in
                OCRTextLine(
                    text: line.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    boundingBox: line.boundingBox
                )
            }
            .filter { !$0.text.isEmpty }
            .sorted(by: isBeforeInReadingOrder)
            .map(\.text)
            .joined(separator: "\n")
    }

    private static func isBeforeInReadingOrder(_ lhs: OCRTextLine, _ rhs: OCRTextLine) -> Bool {
        let lhsTop = lhs.boundingBox.maxY
        let rhsTop = rhs.boundingBox.maxY

        if abs(lhsTop - rhsTop) > rowTolerance {
            return lhsTop > rhsTop
        }

        return lhs.boundingBox.minX < rhs.boundingBox.minX
    }
}
