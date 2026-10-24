import CoreGraphics
import Foundation
import Testing
@testable import Shelf

struct ShelfManagerTests {
    private let size = CGSize(width: 260, height: 200)
    private let screen = CGRect(x: 0, y: 0, width: 1800, height: 1144)

    @Test func centeredOnCursorWhenItFits() {
        let frame = ShelfManager.frame(for: size, centeredAt: CGPoint(x: 900, y: 500), in: screen)
        #expect(frame == CGRect(x: 770, y: 400, width: 260, height: 200))
    }

    @Test(arguments: [
        CGPoint(x: 5, y: 5),
        CGPoint(x: 1795, y: 1140),
        CGPoint(x: 5, y: 1140),
        CGPoint(x: 1795, y: 5),
    ])
    func keptInsideScreenNearEdges(cursor: CGPoint) {
        let frame = ShelfManager.frame(for: size, centeredAt: cursor, in: screen)
        #expect(screen.contains(frame))
        #expect(frame.size == size)
    }

    @Test func respectsScreenOrigin() {
        // A second display to the left of the main one, below the menu bar.
        let secondary = CGRect(x: -1440, y: 0, width: 1440, height: 875)
        let frame = ShelfManager.frame(for: size, centeredAt: CGPoint(x: -1430, y: 870), in: secondary)
        #expect(frame.origin == CGPoint(x: -1440, y: 675))
    }

    @MainActor @Test func opensAtMostMaxShelves() {
        let storage = TemporaryStorage(
            root: FileManager.default.temporaryDirectory.appendingPathComponent("ShelfTests-\(UUID().uuidString)", isDirectory: true)
        )
        defer { storage.removeAll() }
        let manager = ShelfManager(storage: storage)
        let point = CGPoint(x: 400, y: 400)

        var panels = (0..<ShelfManager.maxShelves).compactMap { _ in manager.presentShelf(near: point) }
        defer { panels.forEach { manager.close($0) } }
        #expect(panels.count == ShelfManager.maxShelves)
        #expect(manager.presentShelf(near: point) == nil)

        manager.close(panels.removeLast())
        if let reopened = manager.presentShelf(near: point) {
            panels.append(reopened)
        } else {
            Issue.record("Closing a shelf should make room for another")
        }
    }
}
