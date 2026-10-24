import AppKit
import Carbon.HIToolbox
import Testing
@testable import Shelf

struct HotKeyTests {
    private func keyDown(_ keyCode: Int, _ modifiers: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0,
            context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(keyCode))!
    }

    @Test func carbonModifiers() {
        #expect(HotKey.shelfDefault.carbonModifiers == UInt32(controlKey | optionKey | cmdKey))
        #expect(HotKey(keyCode: 0, modifiers: [.shift, .command, .capsLock]).carbonModifiers == UInt32(shiftKey | cmdKey))
    }

    @Test func eventNeedsControlOptionOrCommand() {
        #expect(HotKey(event: keyDown(kVK_ANSI_N, [.control, .option, .command])) == .shelfDefault)
        #expect(HotKey(event: keyDown(kVK_ANSI_N, [.option])) != nil)
        #expect(HotKey(event: keyDown(kVK_ANSI_N, [])) == nil)
        #expect(HotKey(event: keyDown(kVK_ANSI_N, [.shift])) == nil)
        #expect(HotKey(event: keyDown(kVK_Return, [])) == nil)
        #expect(HotKey(event: keyDown(kVK_F5, [])) != nil)
        #expect(HotKey(event: keyDown(kVK_JIS_Kana, [.command])) == nil)
    }

    @Test func menuStrings() {
        #expect(HotKey(keyCode: UInt16(kVK_Space), modifiers: [.option]).keyEquivalent == " ")
        #expect(HotKey(keyCode: UInt16(kVK_F2), modifiers: []).displayName == "F2")
        #expect(HotKey(keyCode: UInt16(kVK_UpArrow), modifiers: [.shift, .control]).displayName == "⌃⇧↑")
    }

    @Test func preferencesKeepDefaultChangeAndNone() {
        let defaults = UserDefaults(suiteName: "HotKeyTests-\(UUID().uuidString)")!
        #expect(Preferences(defaults: defaults).shelfHotKey == .shelfDefault)

        let changed = HotKey(keyCode: UInt16(kVK_ANSI_S), modifiers: [.option, .shift])
        Preferences(defaults: defaults).shelfHotKey = changed
        #expect(Preferences(defaults: defaults).shelfHotKey == changed)

        Preferences(defaults: defaults).shelfHotKey = nil
        #expect(Preferences(defaults: defaults).shelfHotKey == nil)
    }

    @Test func shortcutChosenInVersion01CarriesOver() {
        let defaults = UserDefaults(suiteName: "HotKeyTests-\(UUID().uuidString)")!
        defaults.set(["keyCode": kVK_F6, "modifiers": 0], forKey: "newShelfHotKey")
        #expect(Preferences(defaults: defaults).shelfHotKey == HotKey(keyCode: UInt16(kVK_F6), modifiers: []))
    }

    @Test func retiredSettingsAreRemoved() {
        let defaults = UserDefaults(suiteName: "HotKeyTests-\(UUID().uuidString)")!
        defaults.set(true, forKey: "placesFinderSelection")
        _ = Preferences(defaults: defaults)
        #expect(defaults.object(forKey: "placesFinderSelection") == nil)
    }
}
