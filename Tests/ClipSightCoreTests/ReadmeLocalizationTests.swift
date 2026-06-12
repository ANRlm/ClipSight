import Foundation
import XCTest

final class ReadmeLocalizationTests: XCTestCase {
    func testDefaultReadmeIsChineseAndLinksToEnglishReadme() throws {
        let readme = try String(contentsOfFile: "README.md", encoding: .utf8)

        XCTAssertTrue(readme.contains("[中文](README.md) | [English](README.en.md)"))
        XCTAssertTrue(readme.contains("原生 macOS 菜单栏 OCR 工具"))
        XCTAssertTrue(readme.contains("## 功能特性"))
    }

    func testEnglishReadmeLinksBackToChineseReadme() throws {
        let readme = try String(contentsOfFile: "README.en.md", encoding: .utf8)

        XCTAssertTrue(readme.contains("[中文](README.md) | [English](README.en.md)"))
        XCTAssertTrue(readme.contains("Native macOS menu bar OCR"))
        XCTAssertTrue(readme.contains("## Features"))
    }
}
