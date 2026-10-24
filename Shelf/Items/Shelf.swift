import Foundation

/// The items of one shelf.
final class Shelf {
    let id = UUID()
    private(set) var items: [ShelfItem] = []

    /// Called after `items` changes.
    var onChange: (() -> Void)?

    /// Security-scoped URLs resolved from bookmarks whose access is held until `releaseAccess()`.
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

    /// Removes the items at `urls`, as after they were dragged out (F6).
    func remove(_ urls: [URL]) {
        let removed = Set(urls.map(\.standardizedFileURL))
        let count = items.count
        items.removeAll { removed.contains($0.url.standardizedFileURL) }
        if items.count != count { onChange?() }
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

    /// Gives up the security-scoped access taken by `refreshFiles()`. Call when the shelf closes.
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
