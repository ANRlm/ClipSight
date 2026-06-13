import Foundation
import XCTest

final class ReadmeLocalizationTests: XCTestCase {
    func testDefaultReadmeIsChineseAndLinksToEnglishReadme() throws {
        let readme = try String(contentsOfFile: "README.md", encoding: .utf8)

        XCTAssertTrue(readme.contains(#"<a href="./README.md">中文</a> | <a href="./README.en.md">English</a>"#))
        XCTAssertFalse(readme.contains("[中文](README.md) | [English](README.en.md)"))
        XCTAssertTrue(readme.contains("原生 macOS 菜单栏 OCR 工具"))
        XCTAssertTrue(readme.contains("## 功能特性"))
        XCTAssertTrue(readme.contains("## 运行要求"))
        XCTAssertTrue(readme.contains("## 开发要求"))
        XCTAssertTrue(readme.range(of: #"## 运行要求\s+- macOS 13 Ventura 或更高版本\s+## 开发要求\s+- Xcode"#, options: .regularExpression) != nil)
        XCTAssertTrue(readme.contains("docs/assets/settings-screenshot-zh.png"))
        XCTAssertTrue(readme.contains("ClipSight-0.5.0-local.dmg"))
        XCTAssertTrue(readme.contains("ClipSight-0.5.0-local.zip"))
        XCTAssertTrue(readme.contains("Control 点击"))
        XCTAssertFalse(readme.contains(["公", "证"].joined()))
        XCTAssertFalse(readme.contains(["Developer", "ID"].joined(separator: " ")))
        XCTAssertFalse(readme.contains("settings-screenshot-placeholder.svg"))
        XCTAssertFalse(readme.contains("ClipSight-0.3.0-local.zip"))
    }

    func testEnglishReadmeLinksBackToChineseReadme() throws {
        let readme = try String(contentsOfFile: "README.en.md", encoding: .utf8)

        XCTAssertTrue(readme.contains(#"<a href="./README.md">中文</a> | <a href="./README.en.md">English</a>"#))
        XCTAssertFalse(readme.contains("[中文](README.md) | [English](README.en.md)"))
        XCTAssertTrue(readme.contains("Native macOS menu bar OCR"))
        XCTAssertTrue(readme.contains("## Features"))
        XCTAssertTrue(readme.contains("## Runtime Requirements"))
        XCTAssertTrue(readme.contains("## Development Requirements"))
        XCTAssertTrue(readme.range(of: #"## Runtime Requirements\s+- macOS 13 Ventura or later\s+## Development Requirements\s+- Xcode"#, options: .regularExpression) != nil)
        XCTAssertTrue(readme.contains("docs/assets/settings-screenshot-en.png"))
        XCTAssertTrue(readme.contains("ClipSight-0.5.0-local.dmg"))
        XCTAssertTrue(readme.contains("ClipSight-0.5.0-local.zip"))
        XCTAssertTrue(readme.contains("Control-click"))
        XCTAssertFalse(readme.contains(String(["n", "o", "t", "a", "r", "i", "z", "e", "d"])))
        XCTAssertFalse(readme.contains(["Developer", "ID"].joined(separator: " ")))
        XCTAssertFalse(readme.contains("settings-screenshot-placeholder.svg"))
        XCTAssertFalse(readme.contains("ClipSight-0.3.0-local.zip"))
    }
}
