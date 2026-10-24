import Foundation

/// The items on the shelf, in the order they were put there.
final class Shelf {
    private(set) var items: [ShelfItem] = []

    /// Called after `items` changes.
    var onChange: (() -> Void)?

    /// Security-scoped URLs resolved from bookmarks whose access is held while their item is on the shelf.
    private var accessedURLs: Set<URL> = []

    /// Adds items in order. A file that is already on the shelf is not added twice.
    func append(_ newItems: [ShelfItem]) {
        var added = false
        for item in newItems {
            if case .file(let reference) = item, items.contains(where: { $0.isFile(at: reference.url) }) {
                continue
            }
            items.append(item)
            added = true
        }
        if added { onChange?() }
    }

    /// Takes the items at `urls` off the shelf (F6, F14) and returns them.
    @discardableResult
    func remove(_ urls: [URL]) -> [ShelfItem] {
        let removing = Set(urls.map(\.standardizedFileURL))
        let removed = items.filter { removing.contains($0.url.standardizedFileURL) }
        guard !removed.isEmpty else { return [] }
        items.removeAll { removing.contains($0.url.standardizedFileURL) }
        for url in removed.map(\.url) where accessedURLs.remove(url) != nil {
            url.stopAccessingSecurityScopedResource()
        }
        // Also lets go of the places files were at before they moved.
        if items.isEmpty { releaseAccess() }
        onChange?()
        return removed
    }

    /// Follows moved or renamed originals and marks deleted ones missing (F10).
    func refreshFiles() {
        let refreshed = items.map { item -> ShelfItem in
            guard case .file(let reference) = item else { return item }
            return .file(reference.refreshed { url in
                if !accessedURLs.contains(url), url.startAccessingSecurityScopedResource() {
                    accessedURLs.insert(url)
                }
            })
        }
        guard refreshed != items else { return }
        items = refreshed
        onChange?()
    }

    /// Gives up all security-scoped access taken by `refreshFiles()`.
    func releaseAccess() {
        accessedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        accessedURLs.removeAll()
    }
}

private extension ShelfItem {
    func isFile(at url: URL) -> Bool {
        guard case .file(let reference) = self else { return false }
        return reference.url.standardizedFileURL == url.standardizedFileURL
    }
}
