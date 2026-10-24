import AppKit
import Carbon.HIToolbox

/// A key combination for a global shortcut: a virtual key code and modifier keys.
struct HotKey: Equatable, Sendable {
    static let shelfDefault = HotKey(keyCode: UInt16(kVK_ANSI_N), modifiers: [.control, .option, .command])

    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection([.control, .option, .shift, .command])
    }

    /// The combination of a key-down event, or nil when it cannot be a global shortcut. It needs ⌃, ⌥ or ⌘
    /// (function keys may go without), so that typing is never taken over, and a key the menu can show.
    init?(event: NSEvent) {
        let hotKey = HotKey(keyCode: event.keyCode, modifiers: event.modifierFlags)
        guard hotKey.keyEquivalent != nil,
              Self.functionKeyCodes.contains(Int(event.keyCode))
                || !hotKey.modifiers.isDisjoint(with: [.control, .option, .command])
        else { return nil }
        self = hotKey
    }

    /// Modifiers in the form `RegisterEventHotKey` takes.
    var carbonModifiers: UInt32 {
        var result = 0
        if modifiers.contains(.control) { result |= controlKey }
        if modifiers.contains(.option) { result |= optionKey }
        if modifiers.contains(.shift) { result |= shiftKey }
        if modifiers.contains(.command) { result |= cmdKey }
        return UInt32(result)
    }

    /// The string for `NSMenuItem.keyEquivalent` (shown together with `modifiers`): a special key's character,
    /// or the character of the key on the current ASCII-capable keyboard layout.
    var keyEquivalent: String? {
        if let special = Self.specialKeys[Int(keyCode)] {
            return special.equivalent.map { String(Character(UnicodeScalar($0)!)) }
        }
        return Self.character(for: keyCode)
    }

    /// The combination as the menu shows it, such as "⌃⌥⌘N".
    var displayName: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + (Self.specialKeys[Int(keyCode)]?.name ?? Self.character(for: keyCode)?.uppercased() ?? "?")
    }

    private static let functionKeyCodes: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ]

    /// Keys whose character is not text. `equivalent` is nil for keys a menu cannot show.
    private static let specialKeys: [Int: (equivalent: Int?, name: String)] = {
        var keys: [Int: (equivalent: Int?, name: String)] = [
            kVK_Space: (0x20, "Space"),
            kVK_Return: (0x0D, "↩"),
            kVK_ANSI_KeypadEnter: (0x03, "⌤"),
            kVK_Tab: (0x09, "⇥"),
            kVK_Delete: (NSBackspaceCharacter, "⌫"),
            kVK_ForwardDelete: (NSDeleteFunctionKey, "⌦"),
            kVK_Escape: (0x1B, "⎋"),
            kVK_Home: (NSHomeFunctionKey, "↖"),
            kVK_End: (NSEndFunctionKey, "↘"),
            kVK_PageUp: (NSPageUpFunctionKey, "⇞"),
            kVK_PageDown: (NSPageDownFunctionKey, "⇟"),
            kVK_LeftArrow: (NSLeftArrowFunctionKey, "←"),
            kVK_RightArrow: (NSRightArrowFunctionKey, "→"),
            kVK_UpArrow: (NSUpArrowFunctionKey, "↑"),
            kVK_DownArrow: (NSDownArrowFunctionKey, "↓"),
            kVK_JIS_Eisu: (nil, "英数"),
            kVK_JIS_Kana: (nil, "かな"),
        ]
        let functionKeys = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
            kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        ]
        for (index, keyCode) in functionKeys.enumerated() {
            keys[keyCode] = (NSF1FunctionKey + index, "F\(index + 1)")
        }
        return keys
    }()

    /// The character `keyCode` types without modifiers on the current ASCII-capable layout (so that a Japanese
    /// input source still gives "n"), or nil when it types none.
    private static func character(for keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        let maxLength = 4
        var characters = [UniChar](repeating: 0, count: maxLength)
        var length = 0
        var deadKeyState: UInt32 = 0
        let status = layoutData.withUnsafeBytes { buffer in
            UCKeyTranslate(
                buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress!, keyCode, UInt16(kUCKeyActionDisplay),
                0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState, maxLength, &length, &characters)
        }
        guard status == noErr, length > 0 else { return nil }
        let string = String(utf16CodeUnits: characters, count: length)
        guard !string.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { return nil }
        return string
    }
}
