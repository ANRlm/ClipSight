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
    @Published public var lastCaptureSummary: LastCaptureSummary?
    @Published public private(set) var hudPlacement: HUDPlacement
    @Published public private(set) var languageSelection: AppLanguageSelection

    private let hotKeyStore: HotKeyStore
    private let hudPlacementStore: HUDPlacementStore
    private let languageStore: AppLanguageStore
    private let preferredLanguages: () -> [String]

    public init(
        hotKeyStore: HotKeyStore = HotKeyStore(),
        hudPlacementStore: HUDPlacementStore = HUDPlacementStore(),
        languageStore: AppLanguageStore = AppLanguageStore(),
        preferredLanguages: @escaping () -> [String] = { Locale.preferredLanguages }
    ) {
        self.hotKeyStore = hotKeyStore
        self.hudPlacementStore = hudPlacementStore
        self.languageStore = languageStore
        self.preferredLanguages = preferredLanguages
        self.hotKey = hotKeyStore.load()
        self.hudPlacement = hudPlacementStore.load()
        let loadedLanguageSelection = languageStore.load()
        self.languageSelection = loadedLanguageSelection
        let initialStrings = AppStrings(language: loadedLanguageSelection.resolved(preferredLanguages: preferredLanguages()))
        self.screenRecordingPermission = initialStrings.screenRecordingPermissionStatus(isGranted: false)
        self.accessibilityPermission = initialStrings.accessibilityPermissionStatus(isGranted: false)
        self.launchAtLoginEnabled = false
        self.isCapturing = false
        self.lastMessage = initialStrings.readyStatus
        self.hotKeyRegistrationError = nil
        self.lastCaptureSummary = nil
    }

    public var language: AppLanguage {
        languageSelection.resolved(preferredLanguages: preferredLanguages())
    }

    public var strings: AppStrings {
        AppStrings(language: language)
    }

    public var shortcutDisplay: String {
        hotKey?.displayString ?? strings.shortcutNotSet
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

    public func setLanguageSelection(_ selection: AppLanguageSelection) {
        languageSelection = selection
        languageStore.save(selection)
        relocalizePermissionStatuses()
        hotKeyRegistrationError = nil
        lastMessage = strings.readyStatus
    }

    public func applyPermissionSnapshot(_ snapshot: PermissionSnapshot) {
        screenRecordingPermission = strings.screenRecordingPermissionStatus(isGranted: snapshot.screenRecording.isGranted)
        accessibilityPermission = strings.accessibilityPermissionStatus(isGranted: snapshot.accessibility.isGranted)
    }

    private func relocalizePermissionStatuses() {
        screenRecordingPermission = strings.screenRecordingPermissionStatus(
            isGranted: screenRecordingPermission.isGranted
        )
        accessibilityPermission = strings.accessibilityPermissionStatus(
            isGranted: accessibilityPermission.isGranted
        )
    }
}
