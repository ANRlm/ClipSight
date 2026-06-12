import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowPresenter {
    private let title: String
    private let size: NSSize
    private let activateApplication: @MainActor () -> Void
    private let windowDelegate: SettingsWindowCloseDelegate
    private var window: NSWindow?

    var windowForTesting: NSWindow? {
        window
    }

    public init(
        title: String = "ClipSight 设置",
        size: NSSize = NSSize(width: 660, height: 620),
        activateApplication: @escaping @MainActor () -> Void = {
            NSApp.setActivationPolicy(.regular)
            NSRunningApplication.current.activate(options: [
                .activateAllWindows,
                .activateIgnoringOtherApps
            ])
        },
        returnToStatusMenuOnly: @escaping @MainActor () -> Void = {
            NSApp.setActivationPolicy(.prohibited)
        }
    ) {
        self.title = title
        self.size = size
        self.activateApplication = activateApplication
        self.windowDelegate = SettingsWindowCloseDelegate(onClose: returnToStatusMenuOnly)
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
        activateApplication()
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
        window.delegate = windowDelegate
        window.center()
        self.window = window
        return window
    }
}

@MainActor
private final class SettingsWindowCloseDelegate: NSObject, NSWindowDelegate {
    private let onClose: @MainActor () -> Void

    init(onClose: @escaping @MainActor () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
