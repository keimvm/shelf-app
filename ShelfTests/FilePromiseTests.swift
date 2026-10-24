import AppKit
import Testing
@testable import Shelf

/// Holds deliveries until the test releases them, including multiple files from one legacy promise.
private final class DeferredPromiseReceiver: NSFilePromiseReceiver {
    private let names: [String]
    private var destination: URL?
    private var reader: ((URL, (any Error)?) -> Void)?
    private var nextFile = 0

    init(names: [String]) {
        self.names = names
        super.init()
    }

    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        return nil
    }

    override var fileNames: [String] { destination == nil ? [] : names }

    override func receivePromisedFiles(
        atDestination destinationDir: URL, options: [AnyHashable: Any] = [:],
        operationQueue: OperationQueue, reader: @escaping (URL, (any Error)?) -> Void
    ) {
        destination = destinationDir
        self.reader = reader
    }

    func deliverNext(error: (any Error)? = nil) {
        let url = destination!.appendingPathComponent(names[nextFile])
        nextFile += 1
        // The failure URL is unspecified by the API; cleanup must not use it to delete a file.
        reader!(error == nil ? url : destination!, error)
    }

    /// Writes before reporting success or failure, like a provider that may leave a partial file.
    func writeNextFile() throws -> URL {
        let url = destination!.appendingPathComponent(names[nextFile])
        try Data("promised contents".utf8).write(to: url)
        return url
    }
}

/// The shelf hides once it is emptied, but not while promised files are still arriving (F7).
@MainActor
final class FilePromiseTests {
    private let storage = TemporaryStorage(
        root: FileManager.default.temporaryDirectory.appendingPathComponent("ShelfTests-\(UUID().uuidString)", isDirectory: true)
    )
    private let controller: ShelfController
    private var reader: InboundReader { controller.reader }
    private var shelf: Shelf { controller.shelf }

    init() {
        controller = ShelfController(storage: storage)
        let frame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        controller.show(near: CGPoint(x: frame.midX, y: frame.midY))
    }

    isolated deinit {
        controller.hide()
        storage.removeAll()
    }

    /// Waits for the delivery's main-actor state update, without timers or scheduling assumptions.
    private func deliver(_ receiver: DeferredPromiseReceiver, error: (any Error)? = nil) async {
        let reader = reader
        let previous = reader.onPendingFilesChanged
        await withCheckedContinuation { continuation in
            reader.onPendingFilesChanged = {
                reader.onPendingFilesChanged = previous
                previous?()
                continuation.resume()
            }
            receiver.deliverNext(error: error)
        }
    }

    private func takeAll() {
        controller.remove(shelf.items.map(\.url), keepingFilesFor: 0)
    }

    private func receive(_ receiver: DeferredPromiseReceiver) {
        let shelf = shelf
        reader.receivePromises([receiver]) { shelf.append($0) }
    }

    @Test func lastItemDoesNotHideShelfWhileAFileIsStillArriving() async {
        shelf.append([.generated(storage.root.appendingPathComponent("existing.txt"), .text)])
        let receiver = DeferredPromiseReceiver(names: ["promised.txt"])

        let shelf = shelf
        let accepted = reader.receivePromises([receiver]) { shelf.append($0) }
        #expect(accepted)
        #expect(reader.pendingFileCount == 1)
        takeAll()
        #expect(shelf.items.isEmpty)
        #expect(controller.isVisible)

        await deliver(receiver)
        #expect(reader.pendingFileCount == 0)
        #expect(shelf.items.map(\.name) == ["promised.txt"])
        #expect(controller.isVisible)

        takeAll()
        #expect(!controller.isVisible)
    }

    @Test func waitsForEveryFileAcrossOverlappingDrops() async {
        let first = DeferredPromiseReceiver(names: ["first.txt", "second.txt"])
        let second = DeferredPromiseReceiver(names: ["third.txt"])
        receive(first)
        receive(second)
        #expect(reader.pendingFileCount == 3)

        await deliver(first)
        takeAll()
        #expect(reader.pendingFileCount == 2)
        #expect(controller.isVisible)

        await deliver(second)
        takeAll()
        #expect(reader.pendingFileCount == 1)
        #expect(controller.isVisible)

        await deliver(first)
        #expect(reader.pendingFileCount == 0)
        #expect(shelf.items.map(\.name) == ["second.txt"])
        #expect(controller.isVisible)
        takeAll()
        #expect(!controller.isVisible)
    }

    @Test func deferredHideFinishesWhenEveryPendingFileFails() async {
        shelf.append([.generated(storage.root.appendingPathComponent("existing.txt"), .text)])
        let receiver = DeferredPromiseReceiver(names: ["first.txt", "second.txt"])
        receive(receiver)
        takeAll()
        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)

        await deliver(receiver, error: error)
        #expect(reader.pendingFileCount == 1)
        #expect(controller.isVisible)
        await deliver(receiver, error: error)
        #expect(reader.pendingFileCount == 0)
        #expect(shelf.items.isEmpty)
        #expect(!controller.isVisible)
    }

    @Test func failedReceptionDoesNotHideAnUnusedEmptyShelf() async {
        let receiver = DeferredPromiseReceiver(names: ["failed.txt"])
        receive(receiver)

        await deliver(receiver, error: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
        #expect(reader.pendingFileCount == 0)
        #expect(controller.isVisible)
        #expect((try? FileManager.default.contentsOfDirectory(atPath: storage.root.path)) == [])
    }

    @Test func failedReceptionDeletesItsPartialFileAndFolder() async throws {
        let receiver = DeferredPromiseReceiver(names: ["partial.txt"])
        receive(receiver)
        let partial = try receiver.writeNextFile()

        await deliver(receiver, error: NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError))

        #expect(reader.pendingFileCount == 0)
        #expect(shelf.items.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: partial.path))
        #expect(!FileManager.default.fileExists(atPath: partial.deletingLastPathComponent().path))
    }

    @Test(arguments: [0, 1])
    func failedReceptionPreservesOtherFilesInTheDrop(failedIndex: Int) async throws {
        let receiver = DeferredPromiseReceiver(names: ["first.txt", "second.txt"])
        receive(receiver)
        var files: [URL] = []
        for index in 0..<2 {
            let url = try receiver.writeNextFile()
            files.append(url)
            let error = index == failedIndex ? NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError) : nil
            await deliver(receiver, error: error)
            if index == 0 {
                // The next provider still needs this folder, even if the first delivery failed.
                #expect(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
            }
        }

        let kept = files[1 - failedIndex]
        #expect(reader.pendingFileCount == 0)
        #expect(shelf.items.map(\.url) == [kept])
        #expect(FileManager.default.fileExists(atPath: kept.path))
        #expect(!FileManager.default.fileExists(atPath: files[failedIndex].path))
        takeAll()
        #expect(!FileManager.default.fileExists(atPath: kept.deletingLastPathComponent().path))
    }
}
