import AppKit
import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var appState: AppState
    private let onRecordHotKey: (HotKey) -> Void
    private let onClearHotKey: () -> Void
    private let onSetLaunchAtLogin: (Bool) -> Void
    private let onSetLanguageSelection: (AppLanguageSelection) -> Void
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
        onSetLanguageSelection: @escaping (AppLanguageSelection) -> Void,
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
        self.onSetLanguageSelection = onSetLanguageSelection
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
        .background(WindowTitleUpdater(title: appState.strings.settingsWindowTitle))
        .onAppear {
            onRefreshPermissions()
        }
    }

    private var content: some View {
        let strings = appState.strings

        return VStack(alignment: .leading, spacing: 14) {
            header

            SettingsGroup(title: strings.shortcutSectionTitle, subtitle: strings.shortcutSectionSubtitle, systemImage: "keyboard") {
                ShortcutRecorderView(
                    currentHotKey: appState.hotKey,
                    strings: strings,
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

            SettingsGroup(title: strings.permissionsSectionTitle, subtitle: strings.permissionsSectionSubtitle, systemImage: "lock.shield") {
                PermissionRow(
                    status: appState.screenRecordingPermission,
                    roleLabel: strings.requiredRoleLabel,
                    actionTitle: strings.openButtonTitle,
                    action: onOpenScreenRecordingSettings
                )
                .help(strings.openScreenRecordingSettingsHint)

                if appState.screenRecordingPermission.requiresAction {
                    InlineNotice(
                        systemImage: "exclamationmark.triangle.fill",
                        text: strings.screenRecordingMissingGuidance,
                        color: .orange
                    )
                    .accessibilityLabel(strings.screenRecordingMissingGuidance)
                }

                SectionDivider()

                PermissionRow(
                    status: appState.accessibilityPermission,
                    roleLabel: strings.optionalRoleLabel,
                    actionTitle: strings.openButtonTitle,
                    action: onOpenAccessibilitySettings
                )
                .help(strings.openAccessibilitySettingsHint)

                SectionDivider()

                HStack {
                    InlineNotice(
                        systemImage: "arrow.triangle.2.circlepath",
                        text: strings.refreshPermissionsNotice,
                        color: .secondary
                    )

                    Spacer(minLength: 12)

                    Button {
                        onRefreshPermissions()
                    } label: {
                        Label(strings.refreshButtonTitle, systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                    .accessibilityLabel(strings.refreshButtonTitle)
                    .accessibilityHint(strings.refreshPermissionsHint)
                    .help(strings.refreshPermissionsHint)
                }
            }

            SettingsGroup(title: strings.systemSectionTitle, subtitle: strings.systemSectionSubtitle, systemImage: "gearshape") {
                SettingsInfoRow(
                    systemImage: "power",
                    title: strings.launchAtLoginTitle,
                    detail: strings.launchAtLoginDetail
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
                    .accessibilityLabel(strings.launchAtLoginTitle)
                    .accessibilityHint(strings.launchAtLoginHint)
                    .help(strings.launchAtLoginHint)
                }

                SectionDivider()

                SettingsInfoRow(
                    systemImage: "globe",
                    title: strings.languageTitle,
                    detail: strings.languageDetail
                ) {
                    Picker(
                        strings.languageTitle,
                        selection: Binding(
                            get: { appState.languageSelection },
                            set: onSetLanguageSelection
                        )
                    ) {
                        ForEach(AppLanguageSelection.allCases) { selection in
                            Text(strings.languageSelectionTitle(selection))
                                .tag(selection)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .frame(width: 126)
                    .accessibilityLabel(strings.languageTitle)
                    .accessibilityHint(strings.languagePickerHint)
                    .help(strings.languagePickerHint)
                }

                SectionDivider()

                SettingsInfoRow(
                    systemImage: "rectangle.and.hand.point.up.left",
                    title: strings.hudPositionTitle,
                    detail: strings.hudPositionDetail
                ) {
                    HStack(spacing: 8) {
                        StatusBadge(
                            text: appState.hudPlacement.summaryLabel(in: strings),
                            systemImage: "scope",
                            color: .accentColor
                        )

                        Button {
                            onEditHUDPlacement()
                        } label: {
                            Label(strings.adjustButtonTitle, systemImage: "cursorarrow.motionlines")
                        }
                        .controlSize(.small)
                        .accessibilityLabel(strings.adjustButtonTitle)
                        .accessibilityHint(strings.adjustHUDPlacementHint)
                        .help(strings.adjustHUDPlacementHint)

                        Button {
                            onResetHUDPlacement()
                        } label: {
                            Label(strings.resetButtonTitle, systemImage: "arrow.counterclockwise")
                        }
                        .controlSize(.small)
                        .accessibilityLabel(strings.resetButtonTitle)
                        .accessibilityHint(strings.resetHUDPlacementHint)
                        .help(strings.resetHUDPlacementHint)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        let strings = appState.strings

        return HStack(spacing: 14) {
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

                Text(strings.settingsHeaderDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            StatusBadge(text: strings.localProcessingBadge, systemImage: "checkmark.shield", color: .green)
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
            .accessibilityLabel("\(actionTitle) \(status.title)")
            .accessibilityHint(status.detail)
        }
        .frame(minHeight: 42)
        .accessibilityElement(children: .combine)
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

private struct WindowTitleUpdater: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        updateTitle(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        updateTitle(for: nsView)
    }

    private func updateTitle(for view: NSView) {
        DispatchQueue.main.async {
            view.window?.title = title
        }
    }
}
