import AppKit
import Testing
@testable import Shelf

struct ShelfPlacementTests {
    private let size = CGSize(width: 260, height: 200)
    private let screen = CGRect(x: 0, y: 0, width: 1800, height: 1144)
    private let anchor = ShelfViewController.hideButtonCenter

    @Test func hideButtonOnCursorWhenItFits() {
        let cursor = CGPoint(x: 900, y: 500)
        let frame = ShelfController.frame(for: size, putting: anchor, at: cursor, in: screen)
        #expect(frame == CGRect(x: 900 - anchor.x, y: 500 - (200 - anchor.y), width: 260, height: 200))
        #expect(CGPoint(x: frame.minX + anchor.x, y: frame.maxY - anchor.y) == cursor)
    }

    @Test(arguments: [
        CGPoint(x: 5, y: 5),
        CGPoint(x: 1795, y: 1140),
        CGPoint(x: 5, y: 1140),
        CGPoint(x: 1795, y: 5),
    ])
    func keptInsideScreenNearEdges(cursor: CGPoint) {
        let frame = ShelfController.frame(for: size, putting: anchor, at: cursor, in: screen)
        #expect(screen.contains(frame))
        #expect(frame.size == size)
    }

    @Test func respectsScreenOrigin() {
        // A second display to the left of the main one, below the menu bar.
        let secondary = CGRect(x: -1440, y: 0, width: 1440, height: 875)
        let frame = ShelfController.frame(for: size, putting: anchor, at: CGPoint(x: -1430, y: 870), in: secondary)
        #expect(frame.origin == CGPoint(x: -1440, y: 675))
    }
}

@MainActor
final class ShelfControllerTests {
    private let storage = TemporaryStorage(
        root: FileManager.default.temporaryDirectory.appendingPathComponent("ShelfTests-\(UUID().uuidString)", isDirectory: true)
    )
    private let controller: ShelfController
    private let pasteboardName = NSPasteboard.Name("dev.keimvm.ShelfTests.\(UUID().uuidString)")
    /// A point on the main screen, away from its edges.
    private let point: CGPoint

    init() {
        controller = ShelfController(storage: storage)
        let frame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        point = CGPoint(x: frame.midX, y: frame.midY)
    }

    isolated deinit {
        controller.hide()
        NSPasteboard(name: pasteboardName).releaseGlobally()
        storage.removeAll()
    }

    /// Shows the shelf and puts `text` on it as a drop would, and returns the generated file.
    private func putText(_ text: String) throws -> URL {
        let pasteboard = NSPasteboard(name: pasteboardName)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        controller.show(near: point)
        let accepted = controller.reader.read(pasteboard) { [controller] items in controller.shelf.append(items) }
        #expect(accepted)
        return try #require(controller.shelf.items.last?.url)
    }

    @Test func toggleShowsAndHides() {
        #expect(!controller.isVisible)
        controller.toggle(near: point)
        #expect(controller.isVisible)
        #expect(controller.contains(point))
        controller.toggle(near: point)
        #expect(!controller.isVisible)
        #expect(!controller.contains(point))
    }

    @Test func showingAgainBringsTheShelfOver() {
        controller.show(near: point)
        let elsewhere = CGPoint(x: point.x + ShelfController.size.width * 2, y: point.y)
        controller.show(near: elsewhere)
        #expect(controller.contains(elsewhere))
        #expect(!controller.contains(point))
    }

    @Test func hidingKeepsTheItems() throws {
        _ = try putText("keep me")
        #expect(controller.isVisible)
        controller.hide()
        #expect(controller.shelf.items.map(\.name) == ["keep me.txt"])
    }

    @Test func takingOutTheLastItemHidesTheShelf() throws {
        let url = try putText("hello")
        controller.remove([url], keepingFilesFor: 0)
        #expect(controller.shelf.items.isEmpty)
        #expect(!controller.isVisible)
    }

    @Test func takenOutFileOutlivesItsItemForAWhile() throws {
        let url = try putText("hello")
        controller.remove([url], keepingFilesFor: ShelfController.temporaryFilesGrace)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func removedFileIsDeletedRightAway() throws {
        let removed = try putText("first")
        let kept = try putText("second")
        controller.remove([removed], keepingFilesFor: 0)
        #expect(!FileManager.default.fileExists(atPath: removed.path))
        #expect(FileManager.default.fileExists(atPath: kept.path))
        #expect(controller.isVisible)
    }

    @Test func clearRemovesEverythingButTheOriginals() throws {
        let original = try storage.makeFolder().appendingPathComponent("original.txt")
        try Data("x".utf8).write(to: original)
        let generated = try putText("note")
        controller.shelf.append([.file(FileReference(url: original))])

        controller.clear()
        #expect(controller.shelf.items.isEmpty)
        #expect(!controller.isVisible)
        #expect(!FileManager.default.fileExists(atPath: generated.path))
        #expect(FileManager.default.fileExists(atPath: original.path))
    }

    @Test func onChangeReportsItemsAndVisibility() throws {
        var changes = 0
        controller.onChange = { changes += 1 }
        controller.show(near: point)
        #expect(changes == 1)
        _ = try putText("hello")
        #expect(changes == 2)
        controller.hide()
        #expect(changes == 3)
    }
}
