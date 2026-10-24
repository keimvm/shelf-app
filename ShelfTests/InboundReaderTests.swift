import AppKit
import Testing
@testable import Shelf

@MainActor
final class InboundReaderTests {
    @MainActor
    private final class Received {
        var items: [ShelfItem] = []
    }

    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ShelfTests-\(UUID().uuidString)", isDirectory: true)
    // A uniquely named pasteboard, so tests never touch the user's clipboard or drag pasteboard.
    private let pasteboardName = NSPasteboard.Name("dev.keimvm.ShelfTests.\(UUID().uuidString)")
    private let pasteboard: NSPasteboard

    init() throws {
        pasteboard = NSPasteboard(name: pasteboardName)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        pasteboard.clearContents()
    }

    deinit {
        NSPasteboard(name: pasteboardName).releaseGlobally()
        try? FileManager.default.removeItem(at: directory)
    }

    private func read() -> (accepted: Bool, items: [ShelfItem]) {
        let received = Received()
        let accepted = InboundReader(storage: TemporaryStorage(root: directory)).read(pasteboard) { received.items += $0 }
        return (accepted, received.items)
    }

    private func makeFile(_ name: String, contents: String = "x") throws -> URL {
        let url = directory.appendingPathComponent("originals", isDirectory: true).appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
        return url
    }

    @Test func fileURLsAreKeptByReference() throws {
        let a = try makeFile("a.txt")
        let b = try makeFile("b.png")
        pasteboard.writeObjects([a as NSURL, b as NSURL])

        let (accepted, items) = read()
        #expect(accepted)
        #expect(items.map(\.url.standardizedFileURL) == [a.standardizedFileURL, b.standardizedFileURL])
        for item in items {
            guard case .file(let reference) = item else {
                Issue.record("expected a file reference, got \(item)")
                continue
            }
            #expect(reference.bookmark != nil)
        }
        // Nothing is generated for files.
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["originals"])
    }

    @Test func fileURLsWinOverText() throws {
        let a = try makeFile("a.txt")
        let item = NSPasteboardItem()
        item.setString(a.absoluteString, forType: .fileURL)
        item.setString("some text", forType: .string)
        pasteboard.writeObjects([item])

        let (_, items) = read()
        #expect(items.count == 1)
        #expect(items.first.map { if case .file = $0 { true } else { false } } == true)
    }

    @Test func webURLBecomesWeblocNamedByTitle() throws {
        let item = NSPasteboardItem()
        item.setString("https://example.com/page", forType: .URL)
        item.setString("Example: Page", forType: InboundReader.urlNameType)
        item.setString("https://example.com/page", forType: .string)
        pasteboard.writeObjects([item])

        let (accepted, items) = read()
        #expect(accepted)
        let url = try #require(items.first?.url)
        #expect(items.first == .generated(url, .webURL))
        #expect(url.lastPathComponent == "Example- Page.webloc")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String]
        #expect(plist == ["URL": "https://example.com/page"])
    }

    @Test func webURLWithoutTitleIsNamedByHost() throws {
        pasteboard.writeObjects([URL(string: "https://www.example.org/a/b")! as NSURL])
        let (_, items) = read()
        #expect(items.first?.name == "www.example.org.webloc")
    }

    @Test(arguments: [
        String(repeating: "a", count: 260),
        String(repeating: "長いページ名", count: 100),
        String(repeating: "👨‍👩‍👧‍👦", count: 100),
    ])
    func longWebPageTitleCanBeSavedTwice(title: String) throws {
        let item = NSPasteboardItem()
        item.setString("https://example.com/page", forType: .URL)
        item.setString(title, forType: InboundReader.urlNameType)
        pasteboard.writeObjects([item])

        let first = read()
        let second = read()
        #expect(first.accepted && second.accepted)
        let a = try #require(first.items.first?.url)
        let b = try #require(second.items.first?.url)
        #expect(a != b)
        #expect(b.lastPathComponent.hasSuffix(" 2.webloc"))
        for url in [a, b] {
            #expect(url.lastPathComponent.utf8.count <= 255)
            #expect(url.pathExtension == "webloc")
            let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String]
            #expect(plist == ["URL": "https://example.com/page"])
        }
    }

    @Test func textBecomesTxtNamedByFirstLine() throws {
        pasteboard.setString("\n  Meeting notes  \nsecond line", forType: .string)

        let (accepted, items) = read()
        #expect(accepted)
        let url = try #require(items.first?.url)
        #expect(items.first == .generated(url, .text))
        #expect(url.lastPathComponent == "Meeting notes.txt")
        #expect(try String(contentsOf: url, encoding: .utf8) == "\n  Meeting notes  \nsecond line")
    }

    @Test func sameTextTwiceGetsNumberedNames() throws {
        pasteboard.setString("hello", forType: .string)
        let first = read().items
        let second = read().items
        #expect(first.map(\.name) == ["hello.txt"])
        #expect(second.map(\.name) == ["hello 2.txt"])
    }

    @Test func emptyPasteboardIsRejected() {
        let (accepted, items) = read()
        #expect(!accepted)
        #expect(items.isEmpty)
    }

    @Test(arguments: [
        ("a/b:c", "a-b-c"),
        ("   ", "テキスト"),
        (".hidden", "hidden"),
        (String(repeating: "あ", count: 60), String(repeating: "あ", count: 40)),
    ])
    func fileNameFromText(text: String, expected: String) {
        #expect(InboundReader.fileName(fromText: text) == expected)
    }
}
