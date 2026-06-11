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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(currentHotKey?.displayString ?? "未设置")
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 110, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))

                Button(isRecording ? "正在录制" : "录制快捷键") {
                    isRecording = true
                }
                .disabled(isRecording)

                Button("清除") {
                    onClear()
                }
                .disabled(currentHotKey == nil)
            }

            if isRecording {
                ShortcutRecorderRepresentable(
                    isRecording: $isRecording,
                    onRecord: onRecord
                )
                .frame(width: 1, height: 1)

                Text("按下快捷键，Esc 取消")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
