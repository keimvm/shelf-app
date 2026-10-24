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

    @Test func directoryIsCreatedPerShelf() throws {
        defer { storage.removeAll() }
        let a = try storage.directory(for: UUID())
        let b = try storage.directory(for: UUID())
        #expect(a != b)
        #expect(exists(a) && exists(b))
        #expect(a.deletingLastPathComponent().standardizedFileURL == storage.root.standardizedFileURL)
    }

    @Test func removeDirectoryDeletesOnlyThatShelf() throws {
        defer { storage.removeAll() }
        let closing = UUID()
        let closingDirectory = try storage.directory(for: closing)
        let otherDirectory = try storage.directory(for: UUID())
        try Data("x".utf8).write(to: closingDirectory.appendingPathComponent("a.txt"))

        #expect(storage.removeDirectory(for: closing))
        #expect(!exists(closingDirectory))
        #expect(exists(otherDirectory))
    }

    @Test func removeAllDeletesLeftovers() throws {
        let directory = try storage.directory(for: UUID())
        try Data("x".utf8).write(to: directory.appendingPathComponent("a.txt"))
        storage.removeAll()
        #expect(!exists(storage.root))
    }

    @Test func uniqueURLNumbersTakenNames() throws {
        defer { storage.removeAll() }
        let directory = try storage.directory(for: UUID())
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
        let directory = try storage.directory(for: UUID())
        try Data().write(to: directory.appendingPathComponent("README"))
        #expect(TemporaryStorage.uniqueURL(for: "README", in: directory).lastPathComponent == "README 2")
    }

    @Test func longNameStaysWritableWhenNumberGainsADigit() throws {
        defer { storage.removeAll() }
        let directory = try storage.directory(for: UUID())
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
        let directory = try storage.directory(for: UUID())
        let name = "a" + String(repeating: "\u{301}", count: 300) + ".webloc"
        let url = TemporaryStorage.uniqueURL(for: name, in: directory)
        #expect(url.lastPathComponent.utf8.count <= 255)
        #expect(url.pathExtension == "webloc")
        try Data("x".utf8).write(to: url, options: .atomic)
    }
}
