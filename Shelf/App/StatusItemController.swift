import AppKit
import ServiceManagement

/// Menu bar item (F1). Its icon shows whether the shelf holds anything and how many items, so hidden
/// items are not forgotten. The menu shows or hides the shelf, empties it, and holds the settings.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    /// Called with the new value when shaking is turned on or off.
    var onShakeChanged: ((Bool) -> Void)?

    private let preferences: Preferences
    private let shelfHotKey: GlobalHotKey
    private let shelf: ShelfController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggleShelf(_:)), keyEquivalent: "")
    private let clearItem = NSMenuItem(title: "シェルフを空にする", action: #selector(clearShelf(_:)), keyEquivalent: "")
    private let shakeItem = NSMenuItem(title: "シェイクで開く", action: #selector(toggleShake(_:)), keyEquivalent: "")
    private var sensitivityItems: [NSMenuItem] = []
    private let loginItem = NSMenuItem(title: "ログイン時に開く", action: #selector(toggleOpenAtLogin(_:)), keyEquivalent: "")
    private var shortcutRecorder: HotKeyRecorder?

    init(preferences: Preferences, shelfHotKey: GlobalHotKey, shelf: ShelfController) {
        self.preferences = preferences
        self.shelfHotKey = shelfHotKey
        self.shelf = shelf
        super.init()

        statusItem.button?.imagePosition = .imageLeading
        statusItem.menu = makeMenu()
        update()
    }

    /// Shows the number of items on the shelf. Call after it changes.
    func update() {
        let count = shelf.shelf.items.count
        statusItem.button?.image = NSImage(
            systemSymbolName: count == 0 ? "tray" : "tray.full",
            accessibilityDescription: count == 0 ? "Shelf" : "Shelf（\(count) 項目）"
        )
        statusItem.button?.title = count == 0 ? "" : "\(count)"
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        for item in [toggleItem, clearItem] {
            item.target = self
            menu.addItem(item)
        }
        let shortcutItem = NSMenuItem(title: "表示のショートカット…", action: #selector(changeShortcut(_:)), keyEquivalent: "")
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
        toggleItem.title = shelf.isVisible ? "シェルフを隠す" : "シェルフを表示"
        // Shown only; the global shortcut is what toggles the shelf. Only a registered one is shown.
        let hotKey = shelfHotKey.hotKey
        toggleItem.keyEquivalent = hotKey?.keyEquivalent ?? ""
        toggleItem.keyEquivalentModifierMask = hotKey?.modifiers ?? []
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

    @objc private func toggleShelf(_ sender: NSMenuItem) {
        shelf.toggle(near: NSEvent.mouseLocation)
    }

    @objc private func clearShelf(_ sender: NSMenuItem) {
        shelf.clear()
    }

    @objc private func changeShortcut(_ sender: NSMenuItem) {
        if let shortcutRecorder {
            shortcutRecorder.show()
            return
        }
        // Released while recording so that pressing the current combination reaches the recorder.
        shelfHotKey.register(nil)
        let recorder = HotKeyRecorder(title: "シェルフを表示するショートカット", hotKey: preferences.shelfHotKey)
        recorder.onCommit = { [unowned self] hotKey in
            guard shelfHotKey.register(hotKey) else { return false }
            preferences.shelfHotKey = hotKey
            return true
        }
        recorder.onClose = { [unowned self] in
            shelfHotKey.register(preferences.shelfHotKey)
            shortcutRecorder = nil
        }
        shortcutRecorder = recorder
        recorder.show()
    }

    @objc private func toggleShake(_ sender: NSMenuItem) {
        preferences.isShakeEnabled.toggle()
        onShakeChanged?(preferences.isShakeEnabled)
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
        if menuItem.action == #selector(clearShelf(_:)) {
            return !shelf.shelf.items.isEmpty
        }
        return true
    }
}
