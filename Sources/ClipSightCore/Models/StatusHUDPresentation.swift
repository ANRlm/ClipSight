import CoreGraphics
import Foundation

public enum StatusHUDPresentation: Equatable, Sendable {
    case success
    case noText
    case failure

    public var message: String {
        message(in: AppStrings(language: .chinese))
    }

    public func message(in strings: AppStrings) -> String {
        switch self {
        case .success:
            strings.hudSuccessMessage
        case .noText:
            strings.hudNoTextMessage
        case .failure:
            strings.hudFailureMessage
        }
    }
}

public struct HUDPlacement: Codable, Equatable, Sendable {
    public static let `default` = HUDPlacement(x: 0.5, y: 0.34)

    public let x: CGFloat
    public let y: CGFloat

    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    public func clamped() -> HUDPlacement {
        HUDPlacement(
            x: Self.clamp(x, lower: 0, upper: 1),
            y: Self.clamp(y, lower: 0, upper: 1)
        )
    }

    public func snappedToHorizontalCenter(in width: CGFloat, threshold: CGFloat) -> HUDPlacement {
        guard width > 0, threshold > 0 else {
            return self
        }

        let distanceFromCenter = abs((x - 0.5) * width)
        guard distanceFromCenter <= threshold else {
            return self
        }

        return HUDPlacement(x: 0.5, y: y)
    }

    var summaryLabel: String {
        summaryLabel(in: AppStrings(language: .chinese))
    }

    func summaryLabel(in strings: AppStrings) -> String {
        abs(x - 0.5) < 0.001 ? strings.placementCenteredLabel : strings.placementCustomLabel
    }

    var isValidNormalized: Bool {
        x.isFinite && y.isFinite && (0 ... 1).contains(x) && (0 ... 1).contains(y)
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

public struct HUDPlacementStore {
    public static let storageKey = "ClipSight.hudPlacement"
    public static let legacyPositionStorageKey = "ClipSight.hudPosition"

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() -> HUDPlacement {
        if let data = userDefaults.data(forKey: Self.storageKey),
           let placement = try? JSONDecoder().decode(HUDPlacement.self, from: data),
           placement.isValidNormalized {
            return placement
        }

        if let rawValue = userDefaults.string(forKey: Self.legacyPositionStorageKey),
           let position = HUDPosition(rawValue: rawValue) {
            return position.placement
        }

        return .default
    }

    public func save(_ placement: HUDPlacement) {
        guard let data = try? JSONEncoder().encode(placement.clamped()) else {
            return
        }

        userDefaults.set(data, forKey: Self.storageKey)
    }

    public func clear() {
        userDefaults.removeObject(forKey: Self.storageKey)
        userDefaults.removeObject(forKey: Self.legacyPositionStorageKey)
    }
}

/// Legacy preset values kept only to migrate existing user defaults.
public enum HUDPosition: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case topCenter
    case center
    case lowerCenter
    case bottomCenter

    public static let `default`: HUDPosition = .lowerCenter

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .topCenter:
            "顶部"
        case .center:
            "居中"
        case .lowerCenter:
            "偏下"
        case .bottomCenter:
            "底部"
        }
    }

    var placement: HUDPlacement {
        switch self {
        case .topCenter:
            HUDPlacement(x: 0.5, y: 0.86)
        case .center:
            HUDPlacement(x: 0.5, y: 0.5)
        case .lowerCenter:
            .default
        case .bottomCenter:
            HUDPlacement(x: 0.5, y: 0.14)
        }
    }
}

public struct HUDPositionStore {
    public static let storageKey = HUDPlacementStore.legacyPositionStorageKey

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() -> HUDPosition {
        guard let rawValue = userDefaults.string(forKey: Self.storageKey),
              let position = HUDPosition(rawValue: rawValue) else {
            return .default
        }

        return position
    }

    public func save(_ position: HUDPosition) {
        userDefaults.set(position.rawValue, forKey: Self.storageKey)
    }

    public func clear() {
        userDefaults.removeObject(forKey: Self.storageKey)
    }
}
