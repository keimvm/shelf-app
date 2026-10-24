import AppKit
import os

/// Turns the pasteboard of a drop into shelf items (F5, F8).
///
/// One kind is taken at a time, in this order: file URLs, file promises, web URLs, text. Files are
/// kept by reference; the other kinds become files in `storage` (promised files as delivered, text as
/// `.txt`, web URLs as `.webloc`).
@MainActor
final class InboundReader {
    static let urlNameType = NSPasteboard.PasteboardType("public.url-name")

    /// Types a drop target should register for.
    static let readableTypes: [NSPasteboard.PasteboardType] =
        [.fileURL, .URL, .string] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }

    let storage: TemporaryStorage

    /// Includes files whose delivery failed until their callback has been handled on the main actor.
    private(set) var pendingFileCount = 0 {
        didSet { onPendingFilesChanged?() }
    }
    var onPendingFilesChanged: (() -> Void)?

    init(storage: TemporaryStorage) {
        self.storage = storage
    }

    private static let promiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()
    nonisolated private static let log = Logger(subsystem: "dev.keimvm.Shelf", category: "inbound")

    /// Reads `pasteboard` and reports the items through `completion` on the main actor.
    /// Call this while handling the drop: promises are requested before returning. Files,
    /// URLs, and text are reported once, before returning; each promised file is reported when it arrives.
    /// Returns `false` when the pasteboard has nothing this app accepts.
    func read(_ pasteboard: NSPasteboard, completion: @escaping @MainActor @Sendable ([ShelfItem]) -> Void) -> Bool {
        let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if !fileURLs.isEmpty {
            completion(fileURLs.map { .file(FileReference(url: $0)) })
            return true
        }

        let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver] ?? []
        if !receivers.isEmpty {
            return receivePromises(receivers, completion: completion)
        }

        let webURLs = (pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []).filter { !$0.isFileURL }
        if !webURLs.isEmpty {
            let names = pasteboard.pasteboardItems?.map { $0.string(forType: Self.urlNameType) } ?? []
            let items = webURLs.enumerated().compactMap { index, url in
                writeWebloc(url, name: names.count == webURLs.count ? names[index] : nil)
            }
            completion(items)
            return !items.isEmpty
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty, let item = writeText(text) {
            completion([item])
            return true
        }
        return false
    }

    @discardableResult
    func receivePromises(_ receivers: [NSFilePromiseReceiver], completion: @escaping @MainActor @Sendable ([ShelfItem]) -> Void) -> Bool {
        // A fresh folder per drop, so promised files with the same name do not collide.
        let destination: URL
        do {
            destination = try storage.makeFolder()
        } catch {
            Self.log.error("Could not create promise folder: \(error.localizedDescription, privacy: .public)")
            return false
        }

        for receiver in receivers {
            receiver.receivePromisedFiles(atDestination: destination, options: [:], operationQueue: Self.promiseQueue) { @Sendable url, error in
                // Runs on `promiseQueue`, not the main actor.
                Task { @MainActor in
                    if let error {
                        Self.log.error("Promised file failed: \(error.localizedDescription, privacy: .public)")
                    } else {
                        completion([.generated(url, .promise)])
                    }
                    // Add a delivered item before allowing the shelf to close.
                    self.pendingFileCount -= 1
                }
            }
            // fileNames is populated by receivePromisedFiles; fileTypes can undercount legacy promises.
            // Even a request that fails without a file name reports an error through its callback.
            pendingFileCount += max(1, receiver.fileNames.count)
        }
        return true
    }

    private func writeText(_ text: String) -> ShelfItem? {
        do {
            let url = TemporaryStorage.uniqueURL(for: "\(Self.fileName(fromText: text)).txt", in: try storage.directory())
            try Data(text.utf8).write(to: url, options: .atomic)
            return .generated(url, .text)
        } catch {
            Self.log.error("Could not write text: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func writeWebloc(_ webURL: URL, name: String?) -> ShelfItem? {
        let title = Self.sanitized(name ?? "") ?? Self.sanitized(webURL.host() ?? "") ?? "リンク"
        do {
            let url = TemporaryStorage.uniqueURL(for: "\(title).webloc", in: try storage.directory())
            let data = try PropertyListSerialization.data(fromPropertyList: ["URL": webURL.absoluteString], format: .xml, options: 0)
            try data.write(to: url, options: .atomic)
            return .generated(url, .webURL)
        } catch {
            Self.log.error("Could not write webloc: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// A file name from the first non-empty line of `text`, at most 40 characters.
    nonisolated static func fileName(fromText text: String) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return sanitized(String(firstLine.prefix(40))) ?? "テキスト"
    }

    /// `name` without path separators and surrounding whitespace, or `nil` when nothing is left.
    nonisolated static func sanitized(_ name: String) -> String? {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return cleaned.isEmpty ? nil : cleaned
    }
}
