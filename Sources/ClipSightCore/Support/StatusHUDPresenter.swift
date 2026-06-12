import AppKit
import OSLog
import QuartzCore
import SwiftUI

@MainActor
public final class StatusHUDPresenter: StatusHUDPresenting {
    nonisolated static let defaultWindowSize = NSSize(width: 280, height: 56)
    nonisolated static let shadowOutsets = NSEdgeInsets(top: 22, left: 24, bottom: 26, right: 24)
    nonisolated static var windowSize: NSSize {
        NSSize(
            width: defaultWindowSize.width + shadowOutsets.left + shadowOutsets.right,
            height: defaultWindowSize.height + shadowOutsets.top + shadowOutsets.bottom
        )
    }

    private let displayDuration: TimeInterval
    private let logger = Logger(subsystem: ClipSightLogging.subsystem, category: ClipSightLogging.Category.hud)
    private let placementProvider: @MainActor () -> HUDPlacement
    private let stringsProvider: @MainActor () -> AppStrings
    private var window: NSPanel?
    private var dismissTask: Task<Void, Never>?

    public init(
        displayDuration: TimeInterval = 1.8,
        placement: @escaping @MainActor () -> HUDPlacement = { .default },
        strings: @escaping @MainActor () -> AppStrings = { AppStrings(language: .chinese) }
    ) {
        self.displayDuration = displayDuration
        self.placementProvider = placement
        self.stringsProvider = strings
    }

    public func show(_ presentation: StatusHUDPresentation) {
        dismissTask?.cancel()

        let window = window ?? makeWindow()
        let contentOrigin = Self.origin(
            for: placementProvider(),
            in: targetScreenVisibleFrame(),
            windowSize: Self.defaultWindowSize
        )
        let finalOrigin = NSPoint(
            x: contentOrigin.x - Self.shadowOutsets.left,
            y: contentOrigin.y - Self.shadowOutsets.bottom
        )
        let startOrigin = NSPoint(x: finalOrigin.x, y: finalOrigin.y - 8)

        window.contentView = StatusHUDContainerView(presentation: presentation, strings: stringsProvider())
        window.setFrame(NSRect(origin: startOrigin, size: Self.windowSize), display: true)
        window.alphaValue = 0
        window.orderFrontRegardless()
        logger.info("Status HUD shown presentation=\(String(describing: presentation), privacy: .public)")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
            window.animator().setFrameOrigin(finalOrigin)
        }

        let displayDuration = displayDuration
        dismissTask = Task { [weak self] in
            let nanoseconds = UInt64(displayDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else {
                return
            }

            self?.hide()
        }
    }

    public func hide() {
        dismissTask?.cancel()
        dismissTask = nil

        guard let window, window.isVisible else {
            return
        }

        let finalOrigin = NSPoint(x: window.frame.origin.x, y: window.frame.origin.y - 6)
        logger.info("Status HUD hidden")
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
            window.animator().setFrameOrigin(finalOrigin)
        } completionHandler: {
            window.orderOut(nil)
        }
    }

    nonisolated static func origin(
        for placement: HUDPlacement,
        in visibleFrame: NSRect,
        windowSize: NSSize
    ) -> NSPoint {
        let horizontalMargin: CGFloat = 18
        let verticalMargin: CGFloat = 34

        let clampedPlacement = placement.clamped()
        let unclampedX = visibleFrame.minX + visibleFrame.width * clampedPlacement.x - windowSize.width / 2
        let unclampedY = visibleFrame.minY + visibleFrame.height * clampedPlacement.y - windowSize.height / 2
        let minX = visibleFrame.minX + horizontalMargin
        let maxX = visibleFrame.maxX - windowSize.width - horizontalMargin
        let minY = visibleFrame.minY + verticalMargin
        let maxY = visibleFrame.maxY - windowSize.height - verticalMargin

        return NSPoint(
            x: clamp(unclampedX, lower: minX, upper: max(minX, maxX)),
            y: clamp(unclampedY, lower: minY, upper: max(minY, maxY))
        )
    }

    private func makeWindow() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        self.window = panel
        return panel
    }

    private func targetScreenVisibleFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first

        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private nonisolated static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

enum StatusHUDCapsuleSurface: Equatable {
    case foreground
}

@MainActor
final class StatusHUDContainerView: NSView {
    private let materialView = NSVisualEffectView()
    private let materialMaskLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private let contentHostingView: TransparentHostingView<StatusHUDContentView>

    var hasCapsuleMaterialMask: Bool {
        materialView.layer?.mask === materialMaskLayer && materialMaskLayer.path != nil
    }

    var hasMaterialMaskImage: Bool {
        materialView.maskImage != nil
    }

    var hasCapsuleShadowPath: Bool {
        layer?.shadowPath != nil
    }

    init(presentation: StatusHUDPresentation, strings: AppStrings = AppStrings(language: .chinese)) {
        self.contentHostingView = TransparentHostingView(
            rootView: StatusHUDContentView(presentation: presentation, strings: strings)
        )
        super.init(frame: NSRect(origin: .zero, size: StatusHUDPresenter.windowSize))
        configureView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool {
        false
    }

    override func layout() {
        super.layout()

        materialView.frame = capsuleFrame
        contentHostingView.frame = capsuleFrame
        updateCapsuleLayers()
    }

    private func configureView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.16
        layer?.shadowRadius = 16
        layer?.shadowOffset = CGSize(width: 0, height: -8)

        materialView.material = .popover
        materialView.blendingMode = .behindWindow
        materialView.state = .active
        materialView.wantsLayer = true
        materialView.layer?.backgroundColor = NSColor.clear.cgColor
        materialView.layer?.masksToBounds = true
        materialView.layer?.mask = materialMaskLayer

        borderLayer.fillColor = nil
        borderLayer.strokeColor = NSColor.separatorColor.withAlphaComponent(0.22).cgColor
        borderLayer.lineWidth = 1

        addSubview(materialView)
        addSubview(contentHostingView)
        layer?.addSublayer(borderLayer)
    }

    private func updateCapsuleLayers() {
        let capsuleBounds = NSRect(origin: .zero, size: capsuleFrame.size)
        let materialPath = CGPath(
            roundedRect: capsuleBounds,
            cornerWidth: capsuleBounds.height / 2,
            cornerHeight: capsuleBounds.height / 2,
            transform: nil
        )
        let shadowPath = CGPath(
            roundedRect: capsuleFrame,
            cornerWidth: capsuleFrame.height / 2,
            cornerHeight: capsuleFrame.height / 2,
            transform: nil
        )

        materialMaskLayer.frame = capsuleBounds
        materialMaskLayer.path = materialPath
        materialView.maskImage = Self.capsuleMaskImage(size: capsuleFrame.size)
        layer?.shadowPath = shadowPath

        borderLayer.frame = bounds
        borderLayer.path = shadowPath
    }

    private var capsuleFrame: NSRect {
        NSRect(
            x: StatusHUDPresenter.shadowOutsets.left,
            y: StatusHUDPresenter.shadowOutsets.bottom,
            width: StatusHUDPresenter.defaultWindowSize.width,
            height: StatusHUDPresenter.defaultWindowSize.height
        )
    }

    private static func capsuleMaskImage(size: NSSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(
                roundedRect: rect,
                xRadius: rect.height / 2,
                yRadius: rect.height / 2
            ).fill()
            return true
        }
    }
}

final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool {
        false
    }

    required init(rootView: Content) {
        super.init(rootView: rootView)
        configureForTransparentContent()
    }

    @available(*, unavailable)
    @MainActor dynamic required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureForTransparentContent()
    }

    private func configureForTransparentContent() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
    }
}

struct StatusHUDContentView: View {
    let presentation: StatusHUDPresentation
    let strings: AppStrings
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 21, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accentColor)
                .frame(width: 28, height: 28)
                .scaleEffect(isVisible ? 1 : 0.82)
                .opacity(isVisible ? 1 : 0.78)

            Text(presentation.message(in: strings))
                .font(.system(size: 17, weight: .semibold, design: .default))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .frame(width: StatusHUDPresenter.defaultWindowSize.width, height: StatusHUDPresenter.defaultWindowSize.height)
        .onAppear {
            startIconAnimation()
        }
    }

    var accentColor: Color {
        switch presentation {
        case .success:
            .green
        case .noText:
            .yellow
        case .failure:
            .red
        }
    }

    private func startIconAnimation() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
            isVisible = true
        }
    }
}

struct StatusHUDCapsuleView: View {
    let presentation: StatusHUDPresentation
    let surface: StatusHUDCapsuleSurface
    let strings: AppStrings
    @Environment(\.colorScheme) private var colorScheme

    init(
        presentation: StatusHUDPresentation,
        surface: StatusHUDCapsuleSurface = .foreground,
        strings: AppStrings = AppStrings(language: .chinese)
    ) {
        self.presentation = presentation
        self.surface = surface
        self.strings = strings
    }

    var body: some View {
        ZStack {
            capsuleSurface

            StatusHUDContentView(presentation: presentation, strings: strings)
        }
        .frame(width: StatusHUDPresenter.defaultWindowSize.width, height: StatusHUDPresenter.defaultWindowSize.height)
        .clipShape(Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.11), lineWidth: 1)
        }
        .compositingGroup()
    }

    @ViewBuilder
    private var capsuleSurface: some View {
        switch surface {
        case .foreground:
            Capsule(style: .continuous)
                .fill(foregroundSurfaceColor)
                .shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 8)
                .shadow(color: accentColor.opacity(0.08), radius: 12, x: 0, y: 5)
        }
    }

    private var foregroundSurfaceColor: Color {
        switch colorScheme {
        case .dark:
            Color(nsColor: .controlBackgroundColor)
        default:
            Color.white
        }
    }

    private var accentColor: Color {
        switch presentation {
        case .success:
            .green
        case .noText:
            .yellow
        case .failure:
            .red
        }
    }
}
