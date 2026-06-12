import XCTest
@testable import ClipSightCore

final class PermissionStatusTests: XCTestCase {
    func testOptionalPermissionDoesNotRequireActionWhenMissing() {
        let status = PermissionStatus(
            title: "辅助功能",
            missingLabel: "可选",
            detail: "不影响 OCR",
            isGranted: false,
            isRequired: false
        )

        XCTAssertEqual(status.statusLabel, "可选")
        XCTAssertFalse(status.requiresAction)
    }

    func testRequiredPermissionRequiresActionWhenMissing() {
        let status = PermissionStatus(
            title: "屏幕录制",
            detail: "允许读取截图",
            isGranted: false
        )

        XCTAssertEqual(status.statusLabel, "需要授权")
        XCTAssertTrue(status.requiresAction)
    }
}
