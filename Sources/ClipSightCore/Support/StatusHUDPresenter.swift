import AppKit
import SwiftUI

@MainActor
public final class StatusHUDPresenter: StatusHUDPresenting {
    private let displayDuration: TimeInterval
    private var window: NSPanel?
    private var dismissTask: Task<Void, Never>?

    public init(displayDuration: TimeInterval = 1.8) {
        self.displayDuration = displayDuration
    }

    public func show(_ presentation: StatusHUDPresentation) {
        dismissTask?.cancel()

        let window = window ?? makeWindow()
        window.contentView = NSHostingView(rootView: StatusHUDView(presentation: presentation))
        position(window)
        window.alphaValue = 0
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }

        dismissTask = Task { [weak self] in
            guard let self else {
                return
            }

            let nanoseconds = UInt64(self.displayDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self.hide()
            }
        }
    }

    public func hide() {
        guard let window else {
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
        }
    }

    private func makeWindow() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 58),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.ignoresMouseEvents = true
        self.window = panel
        return panel
    }

    private func position(_ window: NSWindow) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = window.frame.size
        let x = visibleFrame.midX - size.width / 2
        let y = visibleFrame.maxY - 116
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct StatusHUDView: View {
    let presentation: StatusHUDPresentation

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: presentation.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(presentation.isSuccess ? .green : .orange)

            Text(presentation.message)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .frame(width: 320, height: 58)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
    }
}
