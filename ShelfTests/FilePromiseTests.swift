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
        reader!(url, error)
    }
}

@MainActor
struct FilePromiseTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ShelfTests-\(UUID().uuidString)", isDirectory: true)

    /// Waits for the delivery's main-actor state update, without timers or scheduling assumptions.
    private func deliver(
        _ receiver: DeferredPromiseReceiver, to reader: InboundReader, error: (any Error)? = nil
    ) async {
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

    private func takeAll(from shelf: Shelf, controller: ShelfViewController) {
        let source = ShelfDragSource(urls: shelf.items.map(\.url)) { _, _ in }
        controller.dragOutEnded(source, operation: .copy)
    }

    @Test func lastItemDoesNotCloseShelfWhileAFileIsStillArriving() async {
        defer { try? FileManager.default.removeItem(at: directory) }
        let shelf = Shelf()
        shelf.append([.generated(directory.appendingPathComponent("existing.txt"), .text)])
        let reader = InboundReader(directory: directory)
        let controller = ShelfViewController(shelf: shelf, reader: reader)
        var closes = 0
        controller.onEmptied = { closes += 1 }
        let receiver = DeferredPromiseReceiver(names: ["promised.txt"])

        #expect(reader.receivePromises([receiver]) { shelf.append($0) })
        #expect(reader.pendingFileCount == 1)
        takeAll(from: shelf, controller: controller)
        #expect(shelf.items.isEmpty)
        #expect(closes == 0)

        await deliver(receiver, to: reader)
        #expect(reader.pendingFileCount == 0)
        #expect(shelf.items.map(\.name) == ["promised.txt"])
        #expect(closes == 0)

        takeAll(from: shelf, controller: controller)
        #expect(closes == 1)
    }

    @Test func waitsForEveryFileAcrossOverlappingDrops() async {
        defer { try? FileManager.default.removeItem(at: directory) }
        let shelf = Shelf()
        let reader = InboundReader(directory: directory)
        let controller = ShelfViewController(shelf: shelf, reader: reader)
        var closes = 0
        controller.onEmptied = { closes += 1 }
        let first = DeferredPromiseReceiver(names: ["first.txt", "second.txt"])
        let second = DeferredPromiseReceiver(names: ["third.txt"])
        reader.receivePromises([first]) { shelf.append($0) }
        reader.receivePromises([second]) { shelf.append($0) }
        #expect(reader.pendingFileCount == 3)

        await deliver(first, to: reader)
        takeAll(from: shelf, controller: controller)
        #expect(reader.pendingFileCount == 2)
        #expect(closes == 0)

        await deliver(second, to: reader)
        takeAll(from: shelf, controller: controller)
        #expect(reader.pendingFileCount == 1)
        #expect(closes == 0)

        await deliver(first, to: reader)
        #expect(reader.pendingFileCount == 0)
        #expect(shelf.items.map(\.name) == ["second.txt"])
        #expect(closes == 0)
        takeAll(from: shelf, controller: controller)
        #expect(closes == 1)
    }

    @Test func deferredCloseFinishesWhenEveryPendingFileFails() async {
        defer { try? FileManager.default.removeItem(at: directory) }
        let shelf = Shelf()
        shelf.append([.generated(directory.appendingPathComponent("existing.txt"), .text)])
        let reader = InboundReader(directory: directory)
        let controller = ShelfViewController(shelf: shelf, reader: reader)
        var closes = 0
        controller.onEmptied = { closes += 1 }
        let receiver = DeferredPromiseReceiver(names: ["first.txt", "second.txt"])
        reader.receivePromises([receiver]) { shelf.append($0) }
        takeAll(from: shelf, controller: controller)
        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)

        await deliver(receiver, to: reader, error: error)
        #expect(reader.pendingFileCount == 1)
        #expect(closes == 0)
        await deliver(receiver, to: reader, error: error)
        #expect(reader.pendingFileCount == 0)
        #expect(shelf.items.isEmpty)
        #expect(closes == 1)
    }

    @Test func failedReceptionDoesNotCloseAnUnusedEmptyShelf() async {
        defer { try? FileManager.default.removeItem(at: directory) }
        let shelf = Shelf()
        let reader = InboundReader(directory: directory)
        let controller = ShelfViewController(shelf: shelf, reader: reader)
        var closes = 0
        controller.onEmptied = { closes += 1 }
        let receiver = DeferredPromiseReceiver(names: ["failed.txt"])
        reader.receivePromises([receiver]) { shelf.append($0) }

        await deliver(receiver, to: reader, error: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
        #expect(reader.pendingFileCount == 0)
        #expect(closes == 0)
    }
}
