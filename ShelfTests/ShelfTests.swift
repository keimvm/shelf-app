import Foundation
import Testing
@testable import Shelf

struct ShelfModelTests {
    private func file(_ path: String) -> ShelfItem {
        .file(FileReference(url: URL(fileURLWithPath: path)))
    }

    @Test func appendKeepsOrder() {
        let shelf = Shelf()
        let text = ShelfItem.generated(URL(fileURLWithPath: "/tmp/x/a.txt"), .text)
        shelf.append([file("/tmp/one"), text, file("/tmp/two")])
        #expect(shelf.items.map(\.name) == ["one", "a.txt", "two"])
    }

    @Test func sameFileIsNotAddedTwice() {
        let shelf = Shelf()
        shelf.append([file("/tmp/one")])
        shelf.append([file("/tmp/./one"), file("/tmp/two")])
        #expect(shelf.items.map(\.name) == ["one", "two"])
    }

    @Test func onChangeOnlyWhenSomethingWasAdded() {
        let shelf = Shelf()
        var changes = 0
        shelf.onChange = { changes += 1 }
        shelf.append([file("/tmp/one")])
        shelf.append([file("/tmp/one")])
        shelf.append([])
        #expect(changes == 1)
    }

    @Test func removeTakesOffOnlyThoseURLs() {
        let shelf = Shelf()
        let text = ShelfItem.generated(URL(fileURLWithPath: "/tmp/x/a.txt"), .text)
        shelf.append([file("/tmp/one"), text, file("/tmp/two")])
        var changes = 0
        shelf.onChange = { changes += 1 }

        shelf.remove([URL(fileURLWithPath: "/tmp/./one"), URL(fileURLWithPath: "/tmp/x/a.txt")])
        #expect(shelf.items.map(\.name) == ["two"])
        shelf.remove([URL(fileURLWithPath: "/tmp/elsewhere")])
        #expect(changes == 1)
    }

    @Test func refreshMarksDeletedFilesMissing() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ShelfTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let kept = directory.appendingPathComponent("kept.txt")
        let deleted = directory.appendingPathComponent("deleted.txt")
        try Data("x".utf8).write(to: kept)
        try Data("x".utf8).write(to: deleted)

        let shelf = Shelf()
        defer { shelf.releaseAccess() }
        shelf.append([.file(FileReference(url: kept)), .file(FileReference(url: deleted)), .generated(kept, .text)])
        var changes = 0
        shelf.onChange = { changes += 1 }

        shelf.refreshFiles()
        #expect(changes == 0)
        try FileManager.default.removeItem(at: deleted)
        shelf.refreshFiles()
        #expect(shelf.items.map(\.isAvailable) == [true, false, true])
        #expect(changes == 1)
    }
}
