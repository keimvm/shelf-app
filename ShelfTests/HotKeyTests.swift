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
        #expect(HotKey.newShelfDefault.carbonModifiers == UInt32(controlKey | optionKey | cmdKey))
        #expect(HotKey(keyCode: 0, modifiers: [.shift, .command, .capsLock]).carbonModifiers == UInt32(shiftKey | cmdKey))
    }

    @Test func eventNeedsControlOptionOrCommand() {
        #expect(HotKey(event: keyDown(kVK_ANSI_N, [.control, .option, .command])) == .newShelfDefault)
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
        #expect(Preferences(defaults: defaults).newShelfHotKey == .newShelfDefault)

        let changed = HotKey(keyCode: UInt16(kVK_ANSI_S), modifiers: [.option, .shift])
        Preferences(defaults: defaults).newShelfHotKey = changed
        #expect(Preferences(defaults: defaults).newShelfHotKey == changed)

        Preferences(defaults: defaults).newShelfHotKey = nil
        #expect(Preferences(defaults: defaults).newShelfHotKey == nil)
    }

    @Test func placingFinderSelectionIsOffUntilTurnedOn() {
        let defaults = UserDefaults(suiteName: "HotKeyTests-\(UUID().uuidString)")!
        #expect(!Preferences(defaults: defaults).placesFinderSelection)

        Preferences(defaults: defaults).placesFinderSelection = true
        #expect(Preferences(defaults: defaults).placesFinderSelection)
    }
}
