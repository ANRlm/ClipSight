import Foundation

public struct InitialPermissionPromptStore {
    private let key = "ClipSight.didShowInitialScreenRecordingGuidance"
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var hasShownInitialScreenRecordingGuidance: Bool {
        userDefaults.bool(forKey: key)
    }

    public func markInitialScreenRecordingGuidanceShown() {
        userDefaults.set(true, forKey: key)
    }
}
