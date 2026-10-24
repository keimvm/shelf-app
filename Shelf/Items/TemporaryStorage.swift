import Foundation

/// Per-shelf temporary directories for files the app creates (F8, F9, N5).
///
/// Everything lives under `<container tmp>/Shelves/<shelfID>/`. A shelf's directory is removed when
/// the shelf closes, and leftovers from a previous run are removed at launch.
struct TemporaryStorage: Sendable {
    let root: URL

    init(root: URL = FileManager.default.temporaryDirectory.appendingPathComponent("Shelves", isDirectory: true)) {
        self.root = root
    }

    /// The directory for a shelf, created if needed.
    func directory(for shelfID: UUID) throws -> URL {
        let url = root.appendingPathComponent(shelfID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Deletes a shelf's directory. Returns whether it is gone afterwards.
    @discardableResult
    func removeDirectory(for shelfID: UUID) -> Bool {
        let url = root.appendingPathComponent(shelfID.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: url)
        return !FileManager.default.fileExists(atPath: url.path)
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
