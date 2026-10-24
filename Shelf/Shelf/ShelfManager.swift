import AppKit
import os

/// Creates, places, and closes shelves. Up to `maxShelves` shelves can be open at once (F4).
@MainActor
final class ShelfManager {
    static let shelfSize = CGSize(width: 260, height: 200)
    static let maxShelves = 10
    /// How long generated files outlive a shelf that closed because its items were dragged out. The
    /// destination may still be copying them after the drop.
    static let temporaryFilesGrace: TimeInterval = 30

    private struct Entry {
        let panel: ShelfPanel
        let shelf: Shelf
    }

    private let storage: TemporaryStorage
    private let log = Logger(subsystem: "dev.keimvm.Shelf", category: "shelf")
    private var entries: [Entry] = []

    init(storage: TemporaryStorage) {
        self.storage = storage
    }

    /// Shows a new shelf centered on `point` (global, bottom-left origin), kept inside that screen.
    /// The app is not activated. Returns nil, with a beep, when `maxShelves` are already open.
    @discardableResult
    func presentShelf(near point: CGPoint) -> ShelfPanel? {
        guard entries.count < Self.maxShelves else {
            log.info("Not opening a shelf: \(Self.maxShelves) already open")
            NSSound.beep()
            return nil
        }

        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? CGRect(origin: .zero, size: Self.shelfSize)
        let frame = Self.frame(for: Self.shelfSize, centeredAt: point, in: visibleFrame)

        let shelf = Shelf()
        let directory: URL
        do {
            directory = try storage.directory(for: shelf.id)
        } catch {
            log.error("Could not create shelf directory: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        let panel = ShelfPanel(contentRect: frame)
        let controller = ShelfViewController(shelf: shelf, reader: InboundReader(directory: directory))
        controller.onClose = { [weak self, weak panel] in
            guard let panel else { return }
            self?.close(panel)
        }
        controller.onEmptied = { [weak self, weak panel] in
            guard let panel else { return }
            self?.close(panel, keepingTemporaryFilesFor: Self.temporaryFilesGrace)
        }
        panel.contentViewController = controller
        panel.setFrame(frame, display: false)
        entries.append(Entry(panel: panel, shelf: shelf))
        panel.orderFrontRegardless()
        return panel
    }

    /// Closes the shelf and deletes its temporary directory (F9), after `delay` seconds if given.
    func close(_ panel: ShelfPanel, keepingTemporaryFilesFor delay: TimeInterval = 0) {
        guard let index = entries.firstIndex(where: { $0.panel === panel }) else { return }
        let entry = entries.remove(at: index)
        panel.close()
        entry.shelf.releaseAccess()
        log.info("Closed shelf with \(entry.shelf.items.count) item(s)")

        let shelfID = entry.shelf.id
        guard delay > 0 else {
            removeDirectory(for: shelfID)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.removeDirectory(for: shelfID)
        }
    }

    private func removeDirectory(for shelfID: UUID) {
        let removed = storage.removeDirectory(for: shelfID)
        log.info("Temporary directory removed=\(removed)")
    }

    /// Whether `point` (global, bottom-left origin) is over an open shelf. Used to keep shakes over a
    /// shelf from opening another one (F3).
    func containsShelf(at point: CGPoint) -> Bool {
        entries.contains { $0.panel.isVisible && NSMouseInRect(point, $0.panel.frame, false) }
    }

    /// A frame of `size` centered at `point`, shifted as little as needed to fit in `bounds`.
    nonisolated static func frame(for size: CGSize, centeredAt point: CGPoint, in bounds: CGRect) -> CGRect {
        var origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)
        return CGRect(origin: origin, size: size)
    }
}
