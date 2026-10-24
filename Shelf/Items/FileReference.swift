import Foundation

/// A dropped file, kept by reference only (F8). The original is never written to (N1).
///
/// The security-scoped bookmark is made right at drop time so the file can be found again after a
/// move or rename (F10).
struct FileReference: Equatable, Sendable {
    private(set) var url: URL
    private(set) var bookmark: Data?
    /// Whether `bookmark` is security-scoped. A file that came without a sandbox extension (F13) is
    /// read through the read-only file exception, which cannot make one; it gets a plain bookmark.
    private(set) var isSecurityScoped = true
    /// The original was deleted or moved to the Trash. It is looked for again on the next refresh.
    private(set) var isMissing = false

    init(url: URL) {
        self.url = url
        bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        if bookmark == nil {
            bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            isSecurityScoped = false
        }
    }

    /// The reference after following a move or rename through the bookmark (F10).
    ///
    /// `startAccess` gets each URL resolved from the security-scoped bookmark before it is used;
    /// stopping that access is up to the caller.
    func refreshed(startAccess: (URL) -> Void) -> FileReference {
        var copy = self
        guard let bookmark else {
            copy.isMissing = !Self.isPresent(url)
            return copy
        }
        var isStale = false
        // Resolving a plain bookmark with `.withSecurityScope` fails (verification.md §5).
        let scope: URL.BookmarkResolutionOptions = isSecurityScoped ? .withSecurityScope : []
        guard let resolved = try? URL(
            resolvingBookmarkData: bookmark,
            options: scope.union([.withoutUI, .withoutMounting]),
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            copy.isMissing = true
            return copy
        }
        if isSecurityScoped {
            startAccess(resolved)
        }
        guard Self.isPresent(resolved) else {
            copy.isMissing = true
            return copy
        }
        copy.url = resolved
        copy.isMissing = false
        let creation: URL.BookmarkCreationOptions = isSecurityScoped ? .withSecurityScope : []
        if isStale, let fresh = try? resolved.bookmarkData(options: creation, includingResourceValuesForKeys: nil, relativeTo: nil) {
            copy.bookmark = fresh
        }
        return copy
    }

    /// Whether a file exists at `url` outside the Trash. A bookmark follows a file into the Trash,
    /// but for the user it is deleted.
    static func isPresent(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
            && !url.pathComponents.contains { $0 == ".Trash" || $0 == ".Trashes" }
    }
}
