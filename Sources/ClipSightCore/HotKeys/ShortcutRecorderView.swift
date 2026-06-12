import AppKit
import SwiftUI

public struct ShortcutRecorderView: View {
    private let currentHotKey: HotKey?
    private let onRecord: (HotKey) -> Void
    private let onClear: () -> Void
    @State private var isRecording = false

    public init(
        currentHotKey: HotKey?,
        onRecord: @escaping (HotKey) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.currentHotKey = currentHotKey
        self.onRecord = onRecord
        self.onClear = onClear
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                ShortcutKeyDisplay(hotKey: currentHotKey)

                Spacer(minLength: 12)

                Button {
                    isRecording = true
                } label: {
                    Label(isRecording ? "录制中" : "录制", systemImage: isRecording ? "record.circle" : "keyboard")
                }
                .controlSize(.small)
                .tint(isRecording ? .orange : .accentColor)
                .disabled(isRecording)

                Button {
                    onClear()
                } label: {
                    Label("清除", systemImage: "xmark.circle")
                }
                .controlSize(.small)
                .disabled(currentHotKey == nil)
            }

            if isRecording {
                ShortcutRecorderRepresentable(
                    isRecording: $isRecording,
                    onRecord: onRecord
                )
                .frame(width: 1, height: 1)

                HStack(spacing: 8) {
                    Image(systemName: "record.circle")
                        .font(.caption.weight(.semibold))
                    Text("按下组合键，Esc 取消")
                        .font(.caption.weight(.medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

private struct ShortcutKeyDisplay: View {
    let hotKey: HotKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前快捷键")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                if let hotKey {
                    ForEach(shortcutParts(for: hotKey)) { part in
                        KeyCap(part: part)
                    }
                } else {
                    Text("尚未设置")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                }
            }
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 1)
            }
        }
    }

    private func shortcutParts(for hotKey: HotKey) -> [ShortcutPart] {
        let modifierParts = HotKeyModifier.allCases
            .filter { hotKey.carbonModifiers & $0.carbonFlag != 0 }
            .map { modifier in
                ShortcutPart(symbol: modifier.displayGlyph, label: modifier.displayName, isPrimary: false)
            }

        return modifierParts + [
            ShortcutPart(symbol: hotKey.keyEquivalent.uppercased(), label: "Key", isPrimary: true)
        ]
    }
}

private struct KeyCap: View {
    let part: ShortcutPart

    var body: some View {
        VStack(spacing: 2) {
            Text(part.symbol)
                .font(.system(size: part.isPrimary ? 17 : 16, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(height: 20)

            Text(part.label)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: capWidth, height: 44)
        .background(
            part.isPrimary ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor).opacity(0.42),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(part.isPrimary ? Color.accentColor.opacity(0.34) : Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 1)
        }
    }

    private var capWidth: CGFloat {
        if part.isPrimary {
            return max(52, CGFloat(part.symbol.count) * 8 + 24)
        }

        return 60
    }
}

private struct ShortcutPart: Identifiable {
    let symbol: String
    let label: String
    let isPrimary: Bool

    var id: String {
        "\(symbol)-\(label)-\(isPrimary)"
    }
}

private extension HotKeyModifier {
    var displayName: String {
        switch self {
        case .control:
            "Control"
        case .option:
            "Option"
        case .shift:
            "Shift"
        case .command:
            "Command"
        }
    }
}

private struct ShortcutRecorderRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onRecord: (HotKey) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onRecord = { hotKey in
            onRecord(hotKey)
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.onRecord = { hotKey in
            onRecord(hotKey)
            isRecording = false
        }
        nsView.onCancel = {
            isRecording = false
        }

        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class ShortcutRecorderNSView: NSView {
    var onRecord: ((HotKey) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        guard let hotKey = HotKey(event: event), hotKey.isUsable else {
            NSSound.beep()
            return
        }

        onRecord?(hotKey)
    }
}
