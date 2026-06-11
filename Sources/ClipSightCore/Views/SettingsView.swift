import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var appState: AppState
    private let onRecordHotKey: (HotKey) -> Void
    private let onClearHotKey: () -> Void
    private let onSetLaunchAtLogin: (Bool) -> Void
    private let onRefreshPermissions: () -> Void
    private let onOpenScreenRecordingSettings: () -> Void
    private let onOpenAccessibilitySettings: () -> Void

    public init(
        appState: AppState,
        onRecordHotKey: @escaping (HotKey) -> Void,
        onClearHotKey: @escaping () -> Void,
        onSetLaunchAtLogin: @escaping (Bool) -> Void,
        onRefreshPermissions: @escaping () -> Void,
        onOpenScreenRecordingSettings: @escaping () -> Void,
        onOpenAccessibilitySettings: @escaping () -> Void
    ) {
        self.appState = appState
        self.onRecordHotKey = onRecordHotKey
        self.onClearHotKey = onClearHotKey
        self.onSetLaunchAtLogin = onSetLaunchAtLogin
        self.onRefreshPermissions = onRefreshPermissions
        self.onOpenScreenRecordingSettings = onOpenScreenRecordingSettings
        self.onOpenAccessibilitySettings = onOpenAccessibilitySettings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            Divider()

            settingsSection(title: "快捷键") {
                ShortcutRecorderView(
                    currentHotKey: appState.hotKey,
                    onRecord: onRecordHotKey,
                    onClear: onClearHotKey
                )

                if let hotKeyRegistrationError = appState.hotKeyRegistrationError {
                    Text(hotKeyRegistrationError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            settingsSection(title: "开机启动") {
                Toggle(
                    "登录 macOS 后自动启动 ClipSight",
                    isOn: Binding(
                        get: { appState.launchAtLoginEnabled },
                        set: onSetLaunchAtLogin
                    )
                )
            }

            settingsSection(title: "权限") {
                VStack(alignment: .leading, spacing: 10) {
                    PermissionRow(
                        status: appState.screenRecordingPermission,
                        actionTitle: "打开屏幕录制设置",
                        action: onOpenScreenRecordingSettings
                    )

                    PermissionRow(
                        status: appState.accessibilityPermission,
                        actionTitle: "打开辅助功能设置",
                        action: onOpenAccessibilitySettings
                    )

                    Button("刷新权限状态") {
                        onRefreshPermissions()
                    }
                }
            }

            settingsSection(title: "本地识别") {
                Text("中文和英文 OCR 使用 Apple Vision 在本机完成，不调用网络服务。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 540, alignment: .topLeading)
        .frame(minHeight: 520, alignment: .topLeading)
        .onAppear {
            onRefreshPermissions()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 28, weight: .medium))
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 4) {
                Text("ClipSight")
                    .font(.title2.weight(.semibold))
                Text("框选截图后识别中英文文本并复制到剪贴板")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}

private struct PermissionRow: View {
    let status: PermissionStatus
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.system(size: 16, weight: .medium))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(status.title)
                        .font(.body.weight(.medium))
                    Text(status.statusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(status.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(actionTitle) {
                action()
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private var iconName: String {
        if status.isGranted {
            return "checkmark.circle.fill"
        }

        return status.requiresAction ? "exclamationmark.triangle.fill" : "info.circle.fill"
    }

    private var iconColor: Color {
        if status.isGranted {
            return .green
        }

        return status.requiresAction ? .orange : .secondary
    }
}
