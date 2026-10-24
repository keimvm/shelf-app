import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let storage = TemporaryStorage()
    private lazy var shelf = ShelfController(storage: storage)
    private lazy var dragMonitor = GlobalDragMonitor(preferences: preferences)
    private let shelfHotKey = GlobalHotKey()
    private var statusItemController: StatusItemController?
    /// The unit tests run inside this app. The app then leaves the user's shortcut and the
    /// files of a Shelf running at the same time (same container) alone.
    private let isHostingTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isHostingTests else { return }
        Logger(subsystem: "dev.keimvm.Shelf", category: "app").info("Launched")

        // Files left by a previous run that did not quit normally (F9).
        storage.removeAll()

        shelfHotKey.onPress = { [shelf] in shelf.toggle(near: NSEvent.mouseLocation) }
        shelfHotKey.register(preferences.shelfHotKey)

        dragMonitor.onShake = { [shelf] point in shelf.show(near: point) }
        dragMonitor.isOverShelf = { [shelf] point in shelf.contains(point) }
        if preferences.isShakeEnabled { dragMonitor.start() }

        let statusItemController = StatusItemController(preferences: preferences, shelfHotKey: shelfHotKey, shelf: shelf)
        statusItemController.onShakeChanged = { [dragMonitor] enabled in
            enabled ? dragMonitor.start() : dragMonitor.stop()
        }
        shelf.onChange = { [weak statusItemController] in statusItemController?.update() }
        self.statusItemController = statusItemController
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Nothing generated outlives the app (F9, N5).
        if !isHostingTests { storage.removeAll() }
    }
}
