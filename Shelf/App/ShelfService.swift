import AppKit
import os

/// The service "Shelf に置く" (F13): puts what is selected in any app — files, text, or a web link — on
/// the shelf, from the Services menu or its shortcut.
///
/// The system hands over the selection, with access to its files, so no further entitlement or
/// permission is needed (verification.md §6). Running a service activates this app, so the app the
/// service was run from is activated again and keeps the focus (verification.md §4).
@MainActor
final class ShelfService: NSObject {
    /// Puts the pasteboard's contents on the shelf. Returns whether anything was accepted.
    var onReceive: ((NSPasteboard) -> Bool)?

    private let log = Logger(subsystem: "dev.keimvm.Shelf", category: "service")
    /// The most recently activated app other than this one.
    private var previousApp = NSWorkspace.shared.frontmostApplication

    override init() {
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app != NSRunningApplication.current else { return }
            MainActor.assumeIsolated { self?.previousApp = app }
        }
    }

    /// Named by `NSMessage` in Info.plist.
    @objc(putOnShelf:userData:error:)
    func putOnShelf(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        if onReceive?(pasteboard) != true {
            log.error("The service got nothing the shelf accepts")
            error.pointee = "シェルフに置けるものがありません。" as NSString
        }
        let restored = previousApp?.activate() ?? false
        log.info("Service ran; reactivated the previous app=\(restored)")
    }
}
