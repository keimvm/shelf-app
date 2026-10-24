import AppKit
import Testing
@testable import Shelf

/// The × of each item and the menus that take items off or empty the shelf (F14).
@MainActor
final class ShelfViewControllerTests {
    private let storage = TemporaryStorage(
        root: FileManager.default.temporaryDirectory.appendingPathComponent("ShelfTests-\(UUID().uuidString)", isDirectory: true)
    )
    private let shelf = Shelf()
    private let controller: ShelfViewController
    private let window: NSWindow
    private let first = URL(fileURLWithPath: "/nonexistent/first.txt")
    private let second = URL(fileURLWithPath: "/nonexistent/second.txt")

    init() {
        shelf.append([.generated(first, .text), .generated(second, .text)])
        controller = ShelfViewController(shelf: shelf, reader: InboundReader(storage: storage))
        window = NSWindow(contentViewController: controller)
        window.setContentSize(ShelfController.size)
        controller.view.layoutSubtreeIfNeeded()
    }

    isolated deinit {
        window.close()
        storage.removeAll()
    }

    /// The view of the item named `name`.
    private func itemView(named name: String) throws -> ShelfDragOriginView {
        try #require(Self.descendants(of: controller.view).compactMap { $0 as? ShelfDragOriginView }.first {
            $0.subviews.contains { ($0 as? NSTextField)?.stringValue == name }
        })
    }

    private func removeButton(in itemView: ShelfDragOriginView) throws -> NSButton {
        try #require(itemView.subviews.compactMap { $0 as? NSButton }.first)
    }

    private static func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(descendants(of:))
    }

    @Test func removeButtonTakesOnlyItsItemOff() throws {
        var removed: [URL] = []
        controller.onRemove = { removed = $0 }
        try removeButton(in: itemView(named: "second.txt")).performClick(nil)
        #expect(removed == [second])
    }

    @Test func removeButtonGetsClicksOnlyWhileShown() throws {
        let itemView = try itemView(named: "first.txt")
        let button = try removeButton(in: itemView)
        let center = itemView.convert(NSPoint(x: button.frame.midX, y: button.frame.midY), to: itemView.superview)
        #expect(button.isHidden)
        #expect(itemView.hitTest(center) === itemView)

        button.isHidden = false
        #expect(itemView.hitTest(center) === button)
        // Elsewhere on the item a press still starts a drag.
        let label = itemView.convert(NSPoint(x: itemView.bounds.midX, y: 10), to: itemView.superview)
        #expect(itemView.hitTest(label) === itemView)
    }

    @Test func itemMenuEmptiesTheShelf() throws {
        var cleared = false
        controller.onClear = { cleared = true }
        let menu = try #require(try itemView(named: "first.txt").onMenu?())
        #expect(menu.items.map(\.title) == ["Finder に表示", "シェルフから外す", "", "シェルフを空にする"])
        let clear = try #require(menu.items.last)
        #expect(clear.isEnabled)
        menu.performActionForItem(at: menu.index(of: clear))
        #expect(cleared)
    }

    @Test func shelfMenuEmptiesTheShelfWhenItHoldsItems() throws {
        var cleared = false
        controller.onClear = { cleared = true }
        let menu = try #require(controller.view.menu)
        #expect(menu.items.map(\.title) == ["シェルフを空にする"])

        menu.delegate?.menuNeedsUpdate?(menu)
        #expect(menu.items[0].isEnabled)
        menu.performActionForItem(at: 0)
        #expect(cleared)

        shelf.remove([first, second])
        menu.delegate?.menuNeedsUpdate?(menu)
        #expect(!menu.items[0].isEnabled)
    }
}
