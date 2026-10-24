import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private var statusItemController: StatusItemController?
    private let newShelfHotKey = GlobalHotKey()
    private lazy var dragMonitor = GlobalDragMonitor(preferences: preferences)
    private let storage = TemporaryStorage()
    private lazy var shelfManager = ShelfManager(storage: storage)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Files generated for shelves of a previous run (F9).
        storage.removeAll()

        let openNewShelf = { [shelfManager] in
            _ = shelfManager.presentShelf(near: NSEvent.mouseLocation)
        }
        newShelfHotKey.onPress = openNewShelf
        newShelfHotKey.register(preferences.newShelfHotKey)

        let statusItemController = StatusItemController(preferences: preferences, newShelfHotKey: newShelfHotKey)
        statusItemController.onNewShelf = openNewShelf
        self.statusItemController = statusItemController

        dragMonitor.onShake = { [shelfManager] point in
            _ = shelfManager.presentShelf(near: point)
        }
        dragMonitor.isOverShelf = { [shelfManager] point in
            shelfManager.containsShelf(at: point)
        }
        dragMonitor.start()
    }
}
