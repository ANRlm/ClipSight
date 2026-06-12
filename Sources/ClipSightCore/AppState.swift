import Combine
import Foundation

@MainActor
public final class AppState: ObservableObject {
    @Published public private(set) var hotKey: HotKey?
    @Published public var screenRecordingPermission: PermissionStatus
    @Published public var accessibilityPermission: PermissionStatus
    @Published public var launchAtLoginEnabled: Bool
    @Published public var isCapturing: Bool
    @Published public var lastMessage: String
    @Published public var hotKeyRegistrationError: String?
    @Published public private(set) var hudPlacement: HUDPlacement

    private let hotKeyStore: HotKeyStore
    private let hudPlacementStore: HUDPlacementStore

    public init(
        hotKeyStore: HotKeyStore = HotKeyStore(),
        hudPlacementStore: HUDPlacementStore = HUDPlacementStore()
    ) {
        self.hotKeyStore = hotKeyStore
        self.hudPlacementStore = hudPlacementStore
        self.hotKey = hotKeyStore.load()
        self.hudPlacement = hudPlacementStore.load()
        self.screenRecordingPermission = PermissionStatus(
            title: "屏幕录制",
            detail: "允许 ClipSight 读取框选截图内容",
            isGranted: false
        )
        self.accessibilityPermission = PermissionStatus(
            title: "辅助功能",
            missingLabel: "可选",
            detail: "当前快捷键实现不依赖辅助功能权限",
            isGranted: false,
            isRequired: false
        )
        self.launchAtLoginEnabled = false
        self.isCapturing = false
        self.lastMessage = "就绪"
        self.hotKeyRegistrationError = nil
    }

    public var shortcutDisplay: String {
        hotKey?.displayString ?? "未设置"
    }

    public func setHotKey(_ hotKey: HotKey) {
        self.hotKey = hotKey
        hotKeyStore.save(hotKey)
    }

    public func clearHotKey() {
        self.hotKey = nil
        hotKeyStore.clear()
    }

    public func setHUDPlacement(_ placement: HUDPlacement) {
        let clampedPlacement = placement.clamped()
        hudPlacement = clampedPlacement
        hudPlacementStore.save(clampedPlacement)
    }

    public func resetHUDPlacement() {
        hudPlacement = .default
        hudPlacementStore.clear()
    }

    public func applyPermissionSnapshot(_ snapshot: PermissionSnapshot) {
        screenRecordingPermission = snapshot.screenRecording
        accessibilityPermission = snapshot.accessibility
    }
}
