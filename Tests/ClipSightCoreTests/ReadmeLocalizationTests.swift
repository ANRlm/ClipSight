import Foundation
import XCTest

final class ReadmeLocalizationTests: XCTestCase {
    func testDefaultReadmeIsChineseAndLinksToEnglishReadme() throws {
        let readme = try String(contentsOfFile: "README.md", encoding: .utf8)

        XCTAssertTrue(readme.contains(#"<a href="./README.md">中文</a> | <a href="./README.en.md">English</a>"#))
        XCTAssertFalse(readme.contains("[中文](README.md) | [English](README.en.md)"))
        XCTAssertTrue(readme.contains("原生 macOS 菜单栏 OCR 工具"))
        XCTAssertTrue(readme.contains("## 功能特性"))
        XCTAssertTrue(readme.contains("docs/assets/settings-screenshot-zh.png"))
        XCTAssertFalse(readme.contains("settings-screenshot-placeholder.svg"))
    }

    func testEnglishReadmeLinksBackToChineseReadme() throws {
        let readme = try String(contentsOfFile: "README.en.md", encoding: .utf8)

        XCTAssertTrue(readme.contains(#"<a href="./README.md">中文</a> | <a href="./README.en.md">English</a>"#))
        XCTAssertFalse(readme.contains("[中文](README.md) | [English](README.en.md)"))
        XCTAssertTrue(readme.contains("Native macOS menu bar OCR"))
        XCTAssertTrue(readme.contains("## Features"))
        XCTAssertTrue(readme.contains("docs/assets/settings-screenshot-en.png"))
        XCTAssertFalse(readme.contains("settings-screenshot-placeholder.svg"))
    }
}
