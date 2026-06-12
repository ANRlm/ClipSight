import AppKit
import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var appState: AppState
    private let onRecordHotKey: (HotKey) -> Void
    private let onClearHotKey: () -> Void
    private let onSetLaunchAtLogin: (Bool) -> Void
    private let onEditHUDPlacement: () -> Void
    private let onResetHUDPlacement: () -> Void
    private let onRefreshPermissions: () -> Void
    private let onOpenScreenRecordingSettings: () -> Void
    private let onOpenAccessibilitySettings: () -> Void

    public init(
        appState: AppState,
        onRecordHotKey: @escaping (HotKey) -> Void,
        onClearHotKey: @escaping () -> Void,
        onSetLaunchAtLogin: @escaping (Bool) -> Void,
        onEditHUDPlacement: @escaping () -> Void,
        onResetHUDPlacement: @escaping () -> Void,
        onRefreshPermissions: @escaping () -> Void,
        onOpenScreenRecordingSettings: @escaping () -> Void,
        onOpenAccessibilitySettings: @escaping () -> Void
    ) {
        self.appState = appState
        self.onRecordHotKey = onRecordHotKey
        self.onClearHotKey = onClearHotKey
        self.onSetLaunchAtLogin = onSetLaunchAtLogin
        self.onEditHUDPlacement = onEditHUDPlacement
        self.onResetHUDPlacement = onResetHUDPlacement
        self.onRefreshPermissions = onRefreshPermissions
        self.onOpenScreenRecordingSettings = onOpenScreenRecordingSettings
        self.onOpenAccessibilitySettings = onOpenAccessibilitySettings
    }

    public var body: some View {
        ScrollView(.vertical) {
            content
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 640, alignment: .topLeading)
        .frame(minHeight: 492, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            onRefreshPermissions()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            SettingsGroup(title: "快捷键", subtitle: "全局触发框选 OCR", systemImage: "keyboard") {
                ShortcutRecorderView(
                    currentHotKey: appState.hotKey,
                    onRecord: onRecordHotKey,
                    onClear: onClearHotKey
                )

                if let hotKeyRegistrationError = appState.hotKeyRegistrationError {
                    InlineNotice(
                        systemImage: "exclamationmark.triangle.fill",
                        text: hotKeyRegistrationError,
                        color: .orange
                    )
                }
            }

            SettingsGroup(title: "权限", subtitle: "屏幕录制为必需，辅助功能为可选", systemImage: "lock.shield") {
                PermissionRow(
                    status: appState.screenRecordingPermission,
                    roleLabel: "必需",
                    actionTitle: "打开",
                    action: onOpenScreenRecordingSettings
                )

                SectionDivider()

                PermissionRow(
                    status: appState.accessibilityPermission,
                    roleLabel: "可选",
                    actionTitle: "打开",
                    action: onOpenAccessibilitySettings
                )

                SectionDivider()

                HStack {
                    InlineNotice(
                        systemImage: "arrow.triangle.2.circlepath",
                        text: "从系统设置返回后会自动刷新，也可手动刷新。",
                        color: .secondary
                    )

                    Spacer(minLength: 12)

                    Button {
                        onRefreshPermissions()
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                }
            }

            SettingsGroup(title: "系统", subtitle: "启动行为，本地识别不上传截图内容", systemImage: "gearshape") {
                SettingsInfoRow(
                    systemImage: "power",
                    title: "开机启动",
                    detail: "登录 macOS 后自动启动 ClipSight"
                ) {
                    Toggle(
                        isOn: Binding(
                            get: { appState.launchAtLoginEnabled },
                            set: onSetLaunchAtLogin
                        )
                    ) {
                        EmptyView()
                    }
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.regular)
                }

                SectionDivider()

                SettingsInfoRow(
                    systemImage: "rectangle.and.hand.point.up.left",
                    title: "提示框位置",
                    detail: "拖动设置 OCR 结果提示的显示位置"
                ) {
                    HStack(spacing: 8) {
                        StatusBadge(
                            text: appState.hudPlacement.summaryLabel,
                            systemImage: "scope",
                            color: .accentColor
                        )

                        Button {
                            onEditHUDPlacement()
                        } label: {
                            Label("调整", systemImage: "cursorarrow.motionlines")
                        }
                        .controlSize(.small)

                        Button {
                            onResetHUDPlacement()
                        } label: {
                            Label("重置", systemImage: "arrow.counterclockwise")
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.16), lineWidth: 1)
                    }

                Image(systemName: "text.viewfinder")
                    .font(.system(size: 23, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("ClipSight")
                    .font(.system(size: 21, weight: .semibold))

                Text("框选截图，识别中英文文本，并复制到剪贴板")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            StatusBadge(text: "本地处理", systemImage: "checkmark.shield", color: .green)
        }
        .padding(.bottom, 4)
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.thinMaterial)

                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.16), lineWidth: 1)
        }
    }
}

private struct PermissionRow: View {
    let status: PermissionStatus
    let roleLabel: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(status.title)
                        .font(.system(size: 13, weight: .semibold))

                    Text(roleLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.thinMaterial, in: Capsule())

                    StatusBadge(
                        text: status.statusLabel,
                        systemImage: badgeIconName,
                        color: badgeColor
                    )
                }

                Text(status.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button {
                action()
            } label: {
                Label(actionTitle, systemImage: "arrow.up.right")
            }
            .controlSize(.small)
        }
        .frame(minHeight: 42)
    }

    private var iconName: String {
        if status.isGranted {
            return "checkmark.circle.fill"
        }

        return status.requiresAction ? "exclamationmark.triangle.fill" : "info.circle.fill"
    }

    private var badgeIconName: String {
        status.isGranted ? "checkmark" : (status.requiresAction ? "exclamationmark" : "circle")
    }

    private var iconColor: Color {
        if status.isGranted {
            return .green
        }

        return status.requiresAction ? .orange : .secondary
    }

    private var badgeColor: Color {
        iconColor
    }
}

private struct SettingsInfoRow<Trailing: View>: View {
    let systemImage: String
    let title: String
    let detail: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            trailing()
        }
        .frame(minHeight: 42)
    }
}

private struct StatusBadge: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
    }
}

private struct InlineNotice: View {
    let systemImage: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(color)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.45))
            .frame(height: 1)
    }
}
