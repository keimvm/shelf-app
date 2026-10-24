import AppKit

/// User settings backed by `UserDefaults`.
final class Preferences {
    private enum Key {
        static let shakeEnabled = "shakeEnabled"
        static let shakeSensitivity = "shakeSensitivity"
        static let newShelfHotKey = "newShelfHotKey"
        static let placesFinderSelection = "placesFinderSelection"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.shakeEnabled: true,
            Key.shakeSensitivity: ShakeSensitivity.standard.rawValue,
            Key.newShelfHotKey: Self.dictionary(for: .newShelfDefault),
            Key.placesFinderSelection: false,
        ])
    }

    /// Whether the new-shelf shortcut puts the files selected in Finder on the shelf (F13). Off by
    /// default because it needs permission to automate Finder.
    var placesFinderSelection: Bool {
        get { defaults.bool(forKey: Key.placesFinderSelection) }
        set { defaults.set(newValue, forKey: Key.placesFinderSelection) }
    }

    var isShakeEnabled: Bool {
        get { defaults.bool(forKey: Key.shakeEnabled) }
        set { defaults.set(newValue, forKey: Key.shakeEnabled) }
    }

    var shakeSensitivity: ShakeSensitivity {
        get { defaults.string(forKey: Key.shakeSensitivity).flatMap(ShakeSensitivity.init(rawValue:)) ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: Key.shakeSensitivity) }
    }

    /// The global shortcut for a new shelf. Stored as an empty dictionary when the user chose none, so that
    /// the registered default does not come back.
    var newShelfHotKey: HotKey? {
        get {
            guard let dictionary = defaults.dictionary(forKey: Key.newShelfHotKey),
                  let keyCode = dictionary["keyCode"] as? Int,
                  let modifiers = dictionary["modifiers"] as? Int
            else { return nil }
            return HotKey(keyCode: UInt16(keyCode), modifiers: NSEvent.ModifierFlags(rawValue: UInt(modifiers)))
        }
        set { defaults.set(newValue.map(Self.dictionary(for:)) ?? [:], forKey: Key.newShelfHotKey) }
    }

    private static func dictionary(for hotKey: HotKey) -> [String: Int] {
        ["keyCode": Int(hotKey.keyCode), "modifiers": Int(hotKey.modifiers.rawValue)]
    }
}
