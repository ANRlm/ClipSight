import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowPresenter {
    private let title: String
    private let size: NSSize
    private var window: NSWindow?

    var windowForTesting: NSWindow? {
        window
    }

    public init(
        title: String = "ClipSight 设置",
        size: NSSize = NSSize(width: 660, height: 620)
    ) {
        self.title = title
        self.size = size
    }

    public func show<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        let window = window ?? makeWindow()
        window.title = title ?? self.title
        window.contentView = NSHostingView(rootView: content())
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public func close() {
        window?.close()
    }

    private func makeWindow() -> NSWindow {
        let contentRect = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.minSize = NSSize(
            width: min(size.width, 560),
            height: min(size.height, 420)
        )
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .windowBackgroundColor
        window.appearance = nil
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        return window
    }
}
