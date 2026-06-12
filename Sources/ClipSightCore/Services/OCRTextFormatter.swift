import CoreGraphics
import Foundation

public enum OCRTextFormatter {
    public static func formattedText(from lines: [OCRTextLine]) -> String {
        let cleanedLines = lines
            .map { line in
                OCRTextLine(
                    text: line.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    boundingBox: line.boundingBox
                )
            }
            .filter { !$0.text.isEmpty }

        return groupedRows(from: cleanedLines)
            .flatMap { row in row.lines.sorted(by: isBeforeWithinRow) }
            .map(\.text)
            .joined(separator: "\n")
    }

    private static func groupedRows(from lines: [OCRTextLine]) -> [TextRow] {
        let rowTolerance = rowTolerance(for: lines)
        let sortedByTop = lines.sorted { lhs, rhs in
            if lhs.boundingBox.maxY == rhs.boundingBox.maxY {
                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }

            return lhs.boundingBox.maxY > rhs.boundingBox.maxY
        }

        var rows: [TextRow] = []
        for line in sortedByTop {
            if let index = rows.firstIndex(where: { abs($0.anchorTop - line.boundingBox.maxY) <= rowTolerance }) {
                rows[index].lines.append(line)
            } else {
                rows.append(TextRow(anchorTop: line.boundingBox.maxY, lines: [line]))
            }
        }

        return rows.sorted { lhs, rhs in
            lhs.anchorTop > rhs.anchorTop
        }
    }

    private static func rowTolerance(for lines: [OCRTextLine]) -> CGFloat {
        let heights = lines
            .map { max($0.boundingBox.height, 0.01) }
            .sorted()

        guard !heights.isEmpty else {
            return 0.04
        }

        let medianHeight = heights[heights.count / 2]
        return min(0.08, max(0.018, medianHeight * 0.9))
    }

    private static func isBeforeWithinRow(_ lhs: OCRTextLine, _ rhs: OCRTextLine) -> Bool {
        if lhs.boundingBox.minX == rhs.boundingBox.minX {
            return lhs.boundingBox.maxY > rhs.boundingBox.maxY
        }

        return lhs.boundingBox.minX < rhs.boundingBox.minX
    }

    private struct TextRow {
        let anchorTop: CGFloat
        var lines: [OCRTextLine]
    }
}
