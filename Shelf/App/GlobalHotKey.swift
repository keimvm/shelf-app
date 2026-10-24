import Carbon.HIToolbox

/// A system-wide shortcut. `RegisterEventHotKey` works in the sandbox and needs no Accessibility
/// permission (N3), unlike a global key-down monitor.
@MainActor
final class GlobalHotKey {
    var onPress: (() -> Void)?
    /// The registered combination. Nil when none is set or the system refused it.
    private(set) var hotKey: HotKey?

    private var reference: EventHotKeyRef?

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // Lives as long as the app, so the handler is never removed.
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            let globalHotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData!).takeUnretainedValue()
            MainActor.assumeIsolated { globalHotKey.onPress?() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    /// Replaces the registered combination. Returns false when the system refuses `hotKey` (for example,
    /// another app has registered it); nothing is registered then.
    @discardableResult
    func register(_ hotKey: HotKey?) -> Bool {
        if let reference {
            UnregisterEventHotKey(reference)
        }
        reference = nil
        self.hotKey = nil
        guard let hotKey else { return true }

        let id = EventHotKeyID(signature: OSType(0x5368_6C66), id: 1) // "Shlf"
        let status = RegisterEventHotKey(
            UInt32(hotKey.keyCode), hotKey.carbonModifiers, id, GetApplicationEventTarget(), 0, &reference)
        guard status == noErr else { return false }
        self.hotKey = hotKey
        return true
    }
}
