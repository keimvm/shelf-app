import AppKit
import ServiceManagement

/// Menu bar item (F1): new shelf and its shortcut, shake toggle, sensitivity, open at login, quit.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    /// Called by "新規シェルフ". The menu item stays disabled while this is nil.
    var onNewShelf: (() -> Void)?

    private let preferences: Preferences
    private let newShelfHotKey: GlobalHotKey
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let newShelfItem = NSMenuItem(title: "新規シェルフ", action: #selector(newShelf(_:)), keyEquivalent: "")
    private let shakeItem = NSMenuItem(title: "シェイクで開く", action: #selector(toggleShake(_:)), keyEquivalent: "")
    private var sensitivityItems: [NSMenuItem] = []
    private let loginItem = NSMenuItem(title: "ログイン時に開く", action: #selector(toggleOpenAtLogin(_:)), keyEquivalent: "")
    private var shortcutRecorder: HotKeyRecorder?

    init(preferences: Preferences, newShelfHotKey: GlobalHotKey) {
        self.preferences = preferences
        self.newShelfHotKey = newShelfHotKey
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "tray", accessibilityDescription: "Shelf")
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        newShelfItem.target = self
        menu.addItem(newShelfItem)
        let shortcutItem = NSMenuItem(title: "新規シェルフのショートカット…", action: #selector(changeNewShelfShortcut(_:)), keyEquivalent: "")
        shortcutItem.target = self
        menu.addItem(shortcutItem)
        menu.addItem(.separator())

        shakeItem.target = self
        menu.addItem(shakeItem)

        let sensitivityMenu = NSMenu()
        for sensitivity in ShakeSensitivity.allCases {
            let item = NSMenuItem(title: sensitivity.title, action: #selector(selectSensitivity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = sensitivity.rawValue
            sensitivityMenu.addItem(item)
            sensitivityItems.append(item)
        }
        let sensitivityItem = NSMenuItem(title: "感度", action: nil, keyEquivalent: "")
        sensitivityItem.submenu = sensitivityMenu
        menu.addItem(sensitivityItem)
        menu.addItem(.separator())

        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Shelf を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        // Shown only; the global shortcut is what opens the shelf. Only a registered one is shown.
        let hotKey = newShelfHotKey.hotKey
        newShelfItem.keyEquivalent = hotKey?.keyEquivalent ?? ""
        newShelfItem.keyEquivalentModifierMask = hotKey?.modifiers ?? []
        shakeItem.state = preferences.isShakeEnabled ? .on : .off
        let current = preferences.shakeSensitivity.rawValue
        for item in sensitivityItems {
            item.state = (item.representedObject as? String) == current ? .on : .off
        }
        // The system owns this setting (the user can also change it in System Settings), so it is not stored in Preferences.
        loginItem.state = switch SMAppService.mainApp.status {
        case .enabled: .on
        case .requiresApproval: .mixed
        default: .off
        }
    }

    @objc private func newShelf(_ sender: NSMenuItem) {
        onNewShelf?()
    }

    @objc private func changeNewShelfShortcut(_ sender: NSMenuItem) {
        if let shortcutRecorder {
            shortcutRecorder.show()
            return
        }
        // Released while recording so that pressing the current combination reaches the recorder.
        newShelfHotKey.register(nil)
        let recorder = HotKeyRecorder(title: "新規シェルフのショートカット", hotKey: preferences.newShelfHotKey)
        recorder.onCommit = { [unowned self] hotKey in
            guard newShelfHotKey.register(hotKey) else { return false }
            preferences.newShelfHotKey = hotKey
            return true
        }
        recorder.onClose = { [unowned self] in
            newShelfHotKey.register(preferences.newShelfHotKey)
            shortcutRecorder = nil
        }
        shortcutRecorder = recorder
        recorder.show()
    }

    @objc private func toggleShake(_ sender: NSMenuItem) {
        preferences.isShakeEnabled.toggle()
    }

    @objc private func selectSensitivity(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let sensitivity = ShakeSensitivity(rawValue: raw) else { return }
        preferences.shakeSensitivity = sensitivity
    }

    @objc private func toggleOpenAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled: try service.unregister()
            case .requiresApproval: break
            default: try service.register()
            }
        } catch {
            NSApp.activate()
            NSAlert(error: error).runModal()
            return
        }
        // Registered but turned off in System Settings: only the user can allow it there.
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}

extension StatusItemController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(newShelf(_:)) {
            return onNewShelf != nil
        }
        return true
    }
}
