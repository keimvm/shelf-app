import Foundation
import Testing
@testable import Shelf

struct TemporaryStorageTests {
    private let storage = TemporaryStorage(
        root: FileManager.default.temporaryDirectory.appendingPathComponent("ShelfTests-\(UUID().uuidString)", isDirectory: true)
    )

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func write(_ url: URL) throws -> URL {
        try Data("x".utf8).write(to: url)
        return url
    }

    @Test func foldersAreMadeInsideTheDirectory() throws {
        defer { storage.removeAll() }
        let a = try storage.makeFolder()
        let b = try storage.makeFolder()
        #expect(a != b)
        #expect(exists(a) && exists(b))
        #expect(a.deletingLastPathComponent().standardizedFileURL == storage.root.standardizedFileURL)
    }

    @Test func discardDeletesOnlyThatFile() throws {
        defer { storage.removeAll() }
        let directory = try storage.directory()
        let discarded = try write(directory.appendingPathComponent("a.txt"))
        let kept = try write(directory.appendingPathComponent("b.txt"))

        storage.discard(discarded)
        #expect(!exists(discarded))
        #expect(exists(kept))
        #expect(exists(directory))
    }

    @Test func discardRemovesAFolderWithItsLastFile() throws {
        defer { storage.removeAll() }
        let folder = try storage.makeFolder()
        let first = try write(folder.appendingPathComponent("first.png"))
        let second = try write(folder.appendingPathComponent("second.png"))

        storage.discard(first)
        #expect(exists(folder))
        storage.discard(second)
        #expect(!exists(folder))
        #expect(exists(storage.root))
    }

    @Test func discardNeverTouchesFilesOutsideTheDirectory() throws {
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("ShelfTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        let original = try write(outside.appendingPathComponent("original.txt"))
        let sneaky = storage.root.appendingPathComponent("../\(outside.lastPathComponent)/original.txt")

        storage.discard(original)
        storage.discard(sneaky)
        storage.discard(storage.root)
        #expect(exists(original))
    }

    @Test func removeAllDeletesLeftovers() throws {
        _ = try write(try storage.makeFolder().appendingPathComponent("a.txt"))
        storage.removeAll()
        #expect(!exists(storage.root))
    }

    @Test func uniqueURLNumbersTakenNames() throws {
        defer { storage.removeAll() }
        let directory = try storage.directory()
        let first = TemporaryStorage.uniqueURL(for: "note.txt", in: directory)
        #expect(first.lastPathComponent == "note.txt")
        try Data().write(to: first)
        let second = TemporaryStorage.uniqueURL(for: "note.txt", in: directory)
        #expect(second.lastPathComponent == "note 2.txt")
        try Data().write(to: second)
        #expect(TemporaryStorage.uniqueURL(for: "note.txt", in: directory).lastPathComponent == "note 3.txt")
    }

    @Test func uniqueURLWithoutExtension() throws {
        defer { storage.removeAll() }
        let directory = try storage.directory()
        try Data().write(to: directory.appendingPathComponent("README"))
        #expect(TemporaryStorage.uniqueURL(for: "README", in: directory).lastPathComponent == "README 2")
    }

    @Test func longNameStaysWritableWhenNumberGainsADigit() throws {
        defer { storage.removeAll() }
        let directory = try storage.directory()
        let name = String(repeating: "a", count: 300) + ".webloc"
        var urls: Set<URL> = []
        for _ in 1...12 {
            let url = TemporaryStorage.uniqueURL(for: name, in: directory)
            #expect(url.lastPathComponent.utf8.count <= 255)
            #expect(url.pathExtension == "webloc")
            #expect(urls.insert(url).inserted)
            try Data("x".utf8).write(to: url, options: .atomic)
        }
    }

    @Test func oversizedSingleCharacterStillGetsAWritableName() throws {
        defer { storage.removeAll() }
        let directory = try storage.directory()
        let name = "a" + String(repeating: "\u{301}", count: 300) + ".webloc"
        let url = TemporaryStorage.uniqueURL(for: name, in: directory)
        #expect(url.lastPathComponent.utf8.count <= 255)
        #expect(url.pathExtension == "webloc")
        try Data("x".utf8).write(to: url, options: .atomic)
    }
}
