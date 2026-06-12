import AppKit
import SwiftUI

@MainActor
public final class HUDPlacementEditorPresenter {
    nonisolated static let snapThreshold: CGFloat = 18
    nonisolated static let backdropOpacity = 0.28
    nonisolated static let previewSurface: StatusHUDCapsuleSurface = .foreground
    nonisolated static let previewSurfaceOpacity = 1.0

    private let placementProvider: @MainActor () -> HUDPlacement
    private let onPlacementChange: @MainActor (HUDPlacement) -> Void
    private let stringsProvider: @MainActor () -> AppStrings
    private var window: NSPanel?

    public init(
        placement: @escaping @MainActor () -> HUDPlacement,
        onPlacementChange: @escaping @MainActor (HUDPlacement) -> Void,
        strings: @escaping @MainActor () -> AppStrings = { AppStrings(language: .chinese) }
    ) {
        self.placementProvider = placement
        self.onPlacementChange = onPlacementChange
        self.stringsProvider = strings
    }

    public func show() {
        hide()

        let visibleFrame = targetScreenVisibleFrame()
        let panel = HUDPlacementEditorPanel(
            contentRect: visibleFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .none

        panel.contentView = TransparentHostingView(
            rootView: HUDPlacementEditorView(
                initialPlacement: placementProvider(),
                snapThreshold: Self.snapThreshold,
                backdropOpacity: Self.backdropOpacity,
                previewSurface: Self.previewSurface,
                strings: stringsProvider(),
                onPlacementChange: { [weak self] placement in
                    self?.onPlacementChange(placement)
                },
                onFinish: { [weak self] in
                    self?.hide()
                }
            )
        )

        window = panel
        panel.makeKeyAndOrderFront(nil)
    }

    public func hide() {
        window?.orderOut(nil)
        window = nil
    }

    private func targetScreenVisibleFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first

        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
}

public struct HUDPlacementDraft: Equatable {
    private let initialPlacement: HUDPlacement
    private var currentPlacement: HUDPlacement

    public init(initialPlacement: HUDPlacement) {
        let clampedPlacement = initialPlacement.clamped()
        self.initialPlacement = clampedPlacement
        self.currentPlacement = clampedPlacement
    }

    public mutating func update(_ placement: HUDPlacement) {
        currentPlacement = placement.clamped()
    }

    public var finishedPlacement: HUDPlacement {
        currentPlacement
    }

    public var cancelledPlacement: HUDPlacement {
        initialPlacement
    }
}

private final class HUDPlacementEditorPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }
}

private struct HUDPlacementEditorView: View {
    @State private var draft: HUDPlacementDraft

    let snapThreshold: CGFloat
    let backdropOpacity: Double
    let previewSurface: StatusHUDCapsuleSurface
    let strings: AppStrings
    let onPlacementChange: (HUDPlacement) -> Void
    let onFinish: () -> Void

    init(
        initialPlacement: HUDPlacement,
        snapThreshold: CGFloat,
        backdropOpacity: Double,
        previewSurface: StatusHUDCapsuleSurface,
        strings: AppStrings,
        onPlacementChange: @escaping (HUDPlacement) -> Void,
        onFinish: @escaping () -> Void
    ) {
        _draft = State(initialValue: HUDPlacementDraft(initialPlacement: initialPlacement))
        self.snapThreshold = snapThreshold
        self.backdropOpacity = backdropOpacity
        self.previewSurface = previewSurface
        self.strings = strings
        self.onPlacementChange = onPlacementChange
        self.onFinish = onFinish
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(backdropOpacity)
                    .contentShape(Rectangle())
                    .ignoresSafeArea()

                centerLine(in: proxy.size)

                StatusHUDCapsuleView(presentation: .success, surface: previewSurface, strings: strings)
                    .position(point(for: draft.finishedPlacement, in: proxy.size))
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("hud-placement-editor"))
                            .onChanged { value in
                                draft.update(placement(from: value.location, in: proxy.size))
                            }
                            .onEnded { value in
                                let placement = placement(from: value.location, in: proxy.size)
                                draft.update(placement)
                            }
                    )

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            onFinish()
                        } label: {
                            Label(strings.placementCancelTitle, systemImage: "xmark")
                        }
                        .controlSize(.large)

                        Button {
                            onPlacementChange(draft.finishedPlacement)
                            onFinish()
                        } label: {
                            Label(strings.placementDoneTitle, systemImage: "checkmark")
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                    }
                    .padding(.top, 22)
                    .padding(.trailing, 26)

                    Spacer()
                }
            }
            .coordinateSpace(name: "hud-placement-editor")
            .onExitCommand {
                onFinish()
            }
        }
    }

    private func centerLine(in size: CGSize) -> some View {
        Path { path in
            let x = size.width / 2
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        .stroke(
            Color.accentColor.opacity(centerLineOpacity(in: size.width)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [6, 7])
        )
    }

    private func point(for placement: HUDPlacement, in size: CGSize) -> CGPoint {
        let halfWidth = StatusHUDPresenter.defaultWindowSize.width / 2
        let halfHeight = StatusHUDPresenter.defaultWindowSize.height / 2
        let x = clamp(placement.x * size.width, lower: halfWidth, upper: size.width - halfWidth)
        let y = clamp((1 - placement.y) * size.height, lower: halfHeight, upper: size.height - halfHeight)

        return CGPoint(x: x, y: y)
    }

    private func placement(from location: CGPoint, in size: CGSize) -> HUDPlacement {
        let halfWidth = StatusHUDPresenter.defaultWindowSize.width / 2
        let halfHeight = StatusHUDPresenter.defaultWindowSize.height / 2
        let x = clamp(location.x, lower: halfWidth, upper: size.width - halfWidth) / size.width
        let y = 1 - clamp(location.y, lower: halfHeight, upper: size.height - halfHeight) / size.height

        return HUDPlacement(x: x, y: y)
            .snappedToHorizontalCenter(in: size.width, threshold: snapThreshold)
    }

    private func centerLineOpacity(in width: CGFloat) -> Double {
        abs((draft.finishedPlacement.x - 0.5) * width) <= snapThreshold ? 0.68 : 0.34
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), max(lower, upper))
    }
}
