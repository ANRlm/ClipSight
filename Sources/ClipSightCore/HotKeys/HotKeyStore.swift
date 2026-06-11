import Foundation

public struct HotKeyStore {
    private let key = "ClipSight.hotKey"
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() -> HotKey? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(HotKey.self, from: data)
    }

    public func save(_ hotKey: HotKey) {
        guard let data = try? JSONEncoder().encode(hotKey) else {
            return
        }

        userDefaults.set(data, forKey: key)
    }

    public func clear() {
        userDefaults.removeObject(forKey: key)
    }
}
