import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
public final class PermissionService: PermissionServicing {
    private let workspace: NSWorkspace

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    public func currentSnapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            screenRecording: PermissionStatus(
                title: "屏幕录制",
                detail: "允许 ClipSight 读取框选截图内容",
                isGranted: CGPreflightScreenCaptureAccess()
            ),
            accessibility: PermissionStatus(
                title: "辅助功能",
                missingLabel: "可选",
                detail: "当前快捷键实现不依赖辅助功能权限",
                isGranted: AXIsProcessTrusted(),
                isRequired: false
            )
        )
    }

    public func openScreenRecordingSettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    public func openAccessibilitySettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private func openSettingsPane(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }

        workspace.open(url)
    }
}
