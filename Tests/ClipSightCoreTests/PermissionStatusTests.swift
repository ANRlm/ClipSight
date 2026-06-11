import Testing
@testable import ClipSightCore

struct PermissionStatusTests {
    @Test
    func optionalPermissionDoesNotRequireActionWhenMissing() {
        let status = PermissionStatus(
            title: "辅助功能",
            missingLabel: "可选",
            detail: "不影响 OCR",
            isGranted: false,
            isRequired: false
        )

        #expect(status.statusLabel == "可选")
        #expect(!status.requiresAction)
    }

    @Test
    func requiredPermissionRequiresActionWhenMissing() {
        let status = PermissionStatus(
            title: "屏幕录制",
            detail: "允许读取截图",
            isGranted: false
        )

        #expect(status.statusLabel == "需要授权")
        #expect(status.requiresAction)
    }
}
