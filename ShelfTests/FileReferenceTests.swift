import Foundation
import Testing
@testable import Shelf

final class FileReferenceTests {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ShelfTests-\(UUID().uuidString)", isDirectory: true)

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeFile(_ name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data("x".utf8).write(to: url)
        return url
    }

    private func refresh(_ reference: FileReference) -> FileReference {
        reference.refreshed { _ in }
    }

    @Test func bookmarkIsMadeAtDropTime() throws {
        let reference = FileReference(url: try makeFile("a.txt"))
        #expect(reference.bookmark != nil)
        #expect(!reference.isMissing)
    }

    @Test func followsRename() throws {
        let original = try makeFile("a.txt")
        let reference = FileReference(url: original)
        let renamed = directory.appendingPathComponent("b.txt")
        try FileManager.default.moveItem(at: original, to: renamed)

        let refreshed = refresh(reference)
        #expect(!refreshed.isMissing)
        #expect(refreshed.url.standardizedFileURL.resolvingSymlinksInPath() == renamed.standardizedFileURL.resolvingSymlinksInPath())
    }

    @Test func followsMoveToAnotherFolder() throws {
        let original = try makeFile("a.txt")
        let reference = FileReference(url: original)
        let folder = directory.appendingPathComponent("moved", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let moved = folder.appendingPathComponent("a.txt")
        try FileManager.default.moveItem(at: original, to: moved)

        let refreshed = refresh(reference)
        #expect(!refreshed.isMissing)
        #expect(refreshed.url.lastPathComponent == "a.txt")
        #expect(refreshed.url.deletingLastPathComponent().lastPathComponent == "moved")
    }

    @Test func deletedFileIsMissing() throws {
        let original = try makeFile("a.txt")
        let reference = FileReference(url: original)
        try FileManager.default.removeItem(at: original)

        #expect(refresh(reference).isMissing)
    }

    @Test func fileInTrashIsMissing() throws {
        let original = try makeFile("a.txt")
        let reference = FileReference(url: original)
        let trash = directory.appendingPathComponent(".Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: original, to: trash.appendingPathComponent("a.txt"))

        #expect(refresh(reference).isMissing)
    }

    @Test func fileIsFoundAgainWhenItComesBack() throws {
        let original = try makeFile("a.txt")
        let reference = FileReference(url: original)
        let trash = directory.appendingPathComponent(".Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let trashed = trash.appendingPathComponent("a.txt")
        try FileManager.default.moveItem(at: original, to: trashed)
        let missing = refresh(reference)
        try FileManager.default.moveItem(at: trashed, to: original)

        let restored = refresh(missing)
        #expect(!restored.isMissing)
        #expect(restored.url.lastPathComponent == "a.txt")
    }

    @Test func accessIsStartedOnTheResolvedURL() throws {
        let reference = FileReference(url: try makeFile("a.txt"))
        var accessed: [URL] = []
        _ = reference.refreshed { accessed.append($0) }
        #expect(accessed.map(\.lastPathComponent) == ["a.txt"])
    }
}
