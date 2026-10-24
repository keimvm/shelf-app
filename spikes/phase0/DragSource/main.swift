// Phase 0 helper: an unsandboxed app that starts a file drag from a fixed on-screen spot,
// so the driver can reproduce external drags deterministically. Throwaway code.

import AppKit
import os

let log = Logger(subsystem: "dev.keimvm.ShelfSpike", category: "source")

final class SourceView: NSView, NSDraggingSource {
    let files: [URL]
    private var started = false

    init(frame: NSRect, files: [URL]) {
        self.files = files
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.7).cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) { started = false }

    override func mouseDragged(with event: NSEvent) {
        guard !started else { return }
        started = true
        let items = files.map { url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            item.setDraggingFrame(NSRect(x: 0, y: 0, width: 48, height: 48), contents: NSWorkspace.shared.icon(forFile: url.path))
            return item
        }
        beginDraggingSession(with: items, event: event, source: self)
        log.notice("source drag began files=\(self.files.count, privacy: .public)")
    }

    // Mirror Finder: offer every operation and let the destination choose.
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .move, .generic, .link]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        log.notice("source drag ended operation=\(operation.rawValue, privacy: .public)")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let files = CommandLine.arguments.dropFirst().map { URL(fileURLWithPath: $0) }
        let frame = NSRect(x: 200, y: 300, width: 160, height: 160)
        window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = SourceView(frame: NSRect(origin: .zero, size: frame.size), files: files)
        window.orderFrontRegardless()
        log.notice("source window frame=\(NSStringFromRect(self.window.frame), privacy: .public)")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
