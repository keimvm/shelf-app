import AppKit

/// User settings backed by `UserDefaults`.
final class Preferences {
    private enum Key {
        static let shakeEnabled = "shakeEnabled"
        static let shakeSensitivity = "shakeSensitivity"
        /// Still the 0.1 name, so a shortcut chosen then carries over.
        static let shelfHotKey = "newShelfHotKey"
        /// Settings of earlier versions that no longer exist; removed so that nothing is left behind.
        static let retired = ["placesFinderSelection"]
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.shakeEnabled: true,
            Key.shakeSensitivity: ShakeSensitivity.standard.rawValue,
            Key.shelfHotKey: Self.dictionary(for: .shelfDefault),
        ])
        Key.retired.forEach(defaults.removeObject(forKey:))
    }

    var isShakeEnabled: Bool {
        get { defaults.bool(forKey: Key.shakeEnabled) }
        set { defaults.set(newValue, forKey: Key.shakeEnabled) }
    }

    var shakeSensitivity: ShakeSensitivity {
        get { defaults.string(forKey: Key.shakeSensitivity).flatMap(ShakeSensitivity.init(rawValue:)) ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: Key.shakeSensitivity) }
    }

    /// The global shortcut that shows and hides the shelf (F12). Stored as an empty dictionary when the user
    /// chose none, so that the registered default does not come back.
    var shelfHotKey: HotKey? {
        get {
            guard let dictionary = defaults.dictionary(forKey: Key.shelfHotKey),
                  let keyCode = dictionary["keyCode"] as? Int,
                  let modifiers = dictionary["modifiers"] as? Int
            else { return nil }
            return HotKey(keyCode: UInt16(keyCode), modifiers: NSEvent.ModifierFlags(rawValue: UInt(modifiers)))
        }
        set { defaults.set(newValue.map(Self.dictionary(for:)) ?? [:], forKey: Key.shelfHotKey) }
    }

    private static func dictionary(for hotKey: HotKey) -> [String: Int] {
        ["keyCode": Int(hotKey.keyCode), "modifiers": Int(hotKey.modifiers.rawValue)]
    }
}
