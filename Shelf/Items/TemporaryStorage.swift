import Foundation

/// The files the app writes for the shelf: text, web links, and promised files (F8, F9, N5).
///
/// Everything lives under `<container tmp>/Shelves/`. A file is deleted when its item leaves the shelf,
/// and anything left over is deleted when the app quits and when it launches. Nothing outside that
/// directory is ever deleted (N1).
struct TemporaryStorage: Sendable {
    let root: URL

    init(root: URL = FileManager.default.temporaryDirectory.appendingPathComponent("Shelves", isDirectory: true)) {
        self.root = root
    }

    /// The directory, created if needed.
    func directory() throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// A new folder in the directory, so that files delivered with the same name do not collide.
    func makeFolder() throws -> URL {
        let url = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Deletes a file the app wrote, and the folder from `makeFolder()` it is in once that is empty.
    /// Does nothing for a URL outside the directory.
    func discard(_ url: URL) {
        let base = root.resolvingSymlinksInPath().pathComponents
        let path = url.resolvingSymlinksInPath().pathComponents
        guard path.count > base.count, Array(path.prefix(base.count)) == base else { return }
        try? FileManager.default.removeItem(at: url)
        let folder = url.deletingLastPathComponent()
        if path.count == base.count + 2, (try? FileManager.default.contentsOfDirectory(atPath: folder.path))?.isEmpty == true {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: root)
    }

    /// A URL for `name` in `directory` that does not exist yet: "name.ext", "name 2.ext", …
    /// Keeps the whole name within 255 UTF-8 bytes, including its extension and number.
    static func uniqueURL(for name: String, in directory: URL) -> URL {
        // File URLs can expose decomposed Unicode, which takes more UTF-8 bytes for e.g. ペ or ジ.
        let base = (name as NSString).deletingPathExtension.decomposedStringWithCanonicalMapping
        let ext = (name as NSString).pathExtension
        let extensionSuffix = ext.isEmpty ? "" : ".\(ext)"
        var number = 1
        while true {
            let suffix = (number == 1 ? "" : " \(number)") + extensionSuffix
            let budget = 255 - suffix.utf8.count
            var bytes = 0
            let shortened = base.prefix { character in
                bytes += character.utf8.count
                return bytes <= budget
            }
            let stem = shortened.isEmpty ? "ファイル" : String(shortened)
            let candidate = directory.appendingPathComponent(stem + suffix)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            number += 1
        }
    }
}
