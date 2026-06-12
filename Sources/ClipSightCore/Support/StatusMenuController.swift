import AppKit

@MainActor
public struct StatusMenuActions {
    public let captureOCR: @MainActor () -> Void
    public let openSettings: @MainActor () -> Void
    public let copyDiagnostics: @MainActor () -> Void
    public let quit: @MainActor () -> Void
    public let showSuccessHUD: @MainActor () -> Void
    public let showNoTextHUD: @MainActor () -> Void
    public let showFailureHUD: @MainActor () -> Void
    public let adjustHUDPosition: @MainActor () -> Void

    public init(
        captureOCR: @escaping @MainActor () -> Void,
        openSettings: @escaping @MainActor () -> Void,
        copyDiagnostics: @escaping @MainActor () -> Void,
        quit: @escaping @MainActor () -> Void,
        showSuccessHUD: @escaping @MainActor () -> Void = {},
        showNoTextHUD: @escaping @MainActor () -> Void = {},
        showFailureHUD: @escaping @MainActor () -> Void = {},
        adjustHUDPosition: @escaping @MainActor () -> Void = {}
    ) {
        self.captureOCR = captureOCR
        self.openSettings = openSettings
        self.copyDiagnostics = copyDiagnostics
        self.quit = quit
        self.showSuccessHUD = showSuccessHUD
        self.showNoTextHUD = showNoTextHUD
        self.showFailureHUD = showFailureHUD
        self.adjustHUDPosition = adjustHUDPosition
    }
}

@MainActor
public final class StatusMenuController: NSObject, NSMenuDelegate {
    private let appState: AppState
    private let actions: StatusMenuActions
    private let isDevelopmentQAMenuEnabled: Bool
    private let statusBar: NSStatusBar
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private var isInvalidated = false

    var menuForTesting: NSMenu {
        menu
    }

    public init(
        appState: AppState,
        actions: StatusMenuActions,
        isDevelopmentQAMenuEnabled: Bool = false,
        statusBar: NSStatusBar = .system
    ) {
        self.appState = appState
        self.actions = actions
        self.isDevelopmentQAMenuEnabled = isDevelopmentQAMenuEnabled
        self.statusBar = statusBar
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.menu = NSMenu(title: "ClipSight")
        super.init()
        configureStatusItem()
        rebuildMenu()
    }

    deinit {
        if !isInvalidated {
            statusBar.removeStatusItem(statusItem)
        }
    }

    public func invalidate() {
        guard !isInvalidated else {
            return
        }

        statusBar.removeStatusItem(statusItem)
        isInvalidated = true
    }

    public func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func configureStatusItem() {
        menu.delegate = self
        statusItem.menu = menu

        guard let button = statusItem.button else {
            return
        }

        let image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "ClipSight")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "ClipSight"
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let strings = appState.strings
        let captureItem = actionItem(
            title: appState.isCapturing ? strings.capturingActionTitle : strings.captureActionTitle,
            action: #selector(handleCaptureOCR(_:)),
            systemImage: "viewfinder"
        )
        captureItem.isEnabled = !appState.isCapturing
        menu.addItem(captureItem)

        menu.addItem(.separator())
        menu.addItem(informationalItem(title: "\(strings.shortcutMenuPrefix): \(appState.shortcutDisplay)"))

        if let hotKeyRegistrationError = appState.hotKeyRegistrationError {
            menu.addItem(informationalItem(title: hotKeyRegistrationError))
        }

        if !appState.lastMessage.isEmpty {
            menu.addItem(informationalItem(title: appState.lastMessage))
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(
            title: strings.settingsActionTitle,
            action: #selector(handleOpenSettings(_:)),
            systemImage: "gearshape"
        ))
        menu.addItem(actionItem(
            title: strings.copyDiagnosticsActionTitle,
            action: #selector(handleCopyDiagnostics(_:)),
            systemImage: "doc.on.doc"
        ))

        if isDevelopmentQAMenuEnabled {
            menu.addItem(.separator())
            menu.addItem(developmentMenuItem(strings: strings))
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(
            title: strings.quitActionTitle,
            action: #selector(handleQuit(_:)),
            systemImage: "power"
        ))
    }

    private func developmentMenuItem(strings: AppStrings) -> NSMenuItem {
        let item = NSMenuItem(title: strings.developmentValidationTitle, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: strings.developmentValidationTitle)
        submenu.addItem(actionItem(
            title: strings.showSuccessHUDTitle,
            action: #selector(handleShowSuccessHUD(_:)),
            systemImage: "checkmark.circle"
        ))
        submenu.addItem(actionItem(
            title: strings.showNoTextHUDTitle,
            action: #selector(handleShowNoTextHUD(_:)),
            systemImage: "exclamationmark.circle"
        ))
        submenu.addItem(actionItem(
            title: strings.showFailureHUDTitle,
            action: #selector(handleShowFailureHUD(_:)),
            systemImage: "xmark.circle"
        ))
        submenu.addItem(actionItem(
            title: strings.adjustHUDPositionTitle,
            action: #selector(handleAdjustHUDPosition(_:)),
            systemImage: "cursorarrow.motionlines"
        ))
        item.submenu = submenu
        return item
    }

    private func actionItem(title: String, action: Selector, systemImage: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = Self.menuImage(systemName: systemImage)
        return item
    }

    private func informationalItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private static func menuImage(systemName: String) -> NSImage? {
        let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    @objc private func handleCaptureOCR(_ sender: NSMenuItem) {
        actions.captureOCR()
    }

    @objc private func handleOpenSettings(_ sender: NSMenuItem) {
        actions.openSettings()
    }

    @objc private func handleCopyDiagnostics(_ sender: NSMenuItem) {
        actions.copyDiagnostics()
    }

    @objc private func handleQuit(_ sender: NSMenuItem) {
        actions.quit()
    }

    @objc private func handleShowSuccessHUD(_ sender: NSMenuItem) {
        actions.showSuccessHUD()
    }

    @objc private func handleShowNoTextHUD(_ sender: NSMenuItem) {
        actions.showNoTextHUD()
    }

    @objc private func handleShowFailureHUD(_ sender: NSMenuItem) {
        actions.showFailureHUD()
    }

    @objc private func handleAdjustHUDPosition(_ sender: NSMenuItem) {
        actions.adjustHUDPosition()
    }
}
