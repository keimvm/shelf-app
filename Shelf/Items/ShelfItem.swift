import Foundation

/// One entry on a shelf.
enum ShelfItem: Equatable, Sendable {
    /// What a generated file was made from.
    enum Kind: Equatable, Sendable {
        case promise, text, webURL
    }

    /// A file dropped by reference.
    case file(FileReference)
    /// A file the app wrote into the shelf's temporary directory.
    case generated(URL, Kind)

    var url: URL {
        switch self {
        case .file(let reference): reference.url
        case .generated(let url, _): url
        }
    }

    var name: String { url.lastPathComponent }

    /// Whether the item can be dragged out. A file whose original is gone cannot (F10).
    var isAvailable: Bool {
        if case .file(let reference) = self { return !reference.isMissing }
        return true
    }

    /// For logs; contains no user data.
    var kindDescription: String {
        switch self {
        case .file: "file"
        case .generated(_, let kind): "\(kind)"
        }
    }
}
