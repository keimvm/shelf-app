// Phase 0 spike: verifies U1–U4 from docs/verification.md inside the App Sandbox.
// Throwaway code. All findings are written to the unified log (subsystem dev.keimvm.ShelfSpike).

import AppKit
import os

let log = Logger(subsystem: "dev.keimvm.ShelfSpike", category: "spike")

func note(_ message: String) {
    log.notice("\(message, privacy: .public)")
}

// MARK: - U1 / U2: global drag observation

final class DragObserver {
    private var monitors: [Any] = []
    private var pollTimer: Timer?

    private var gestureActive = false
    private var changeCountAtDown = 0
    private var globalDragged = 0
    private var localDragged = 0
    private var draggedAfterPasteboardChange = 0
    private var pollSamples = 0
    private var pollSamplesWhilePasteboardChanged = 0
    private var pasteboardChanged = false
    private var typesAtChange: [String] = []

    private let dragPasteboard = NSPasteboard(name: .drag)

    func start() {
        note("U2 accessBehavior drag=\(dragPasteboard.accessBehavior.rawValue) general=\(NSPasteboard.general.accessBehavior.rawValue)")

        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event, local: false)
        }) {
            monitors.append(global)
        } else {
            note("U1 addGlobalMonitorForEvents returned nil")
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event, local: true)
            return event
        }) {
            monitors.append(local)
        }

        // Fallback candidate: poll the cursor while the left button is held.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func handle(_ event: NSEvent, local: Bool) {
        switch event.type {
        case .leftMouseDown:
            begin()
        case .leftMouseDragged:
            if !gestureActive { begin() }
            if local { localDragged += 1 } else { globalDragged += 1 }
            checkPasteboard()
            if pasteboardChanged { draggedAfterPasteboardChange += 1 }
        case .leftMouseUp:
            finish(source: local ? "local" : "global")
        default:
            break
        }
    }

    private func poll() {
        guard NSEvent.pressedMouseButtons & 1 == 1 else {
            if gestureActive && globalDragged == 0 && localDragged == 0 && pollSamples > 0 {
                // Mouse-up was never delivered by a monitor; close the gesture from polling.
                finish(source: "poll")
            }
            return
        }
        if !gestureActive { begin() }
        pollSamples += 1
        checkPasteboard()
        if pasteboardChanged { pollSamplesWhilePasteboardChanged += 1 }
    }

    private func begin() {
        gestureActive = true
        changeCountAtDown = dragPasteboard.changeCount
        globalDragged = 0
        localDragged = 0
        draggedAfterPasteboardChange = 0
        pollSamples = 0
        pollSamplesWhilePasteboardChanged = 0
        pasteboardChanged = false
        typesAtChange = []
    }

    private func checkPasteboard() {
        guard !pasteboardChanged, dragPasteboard.changeCount != changeCountAtDown else { return }
        pasteboardChanged = true
        // U2: reading `types` only, never contents, during the drag.
        typesAtChange = dragPasteboard.types?.map(\.rawValue) ?? []
        note("U2 drag pasteboard changed \(changeCountAtDown)->\(dragPasteboard.changeCount) types=\(typesAtChange)")
    }

    private func finish(source: String) {
        guard gestureActive else { return }
        gestureActive = false
        note("U1 gesture end(\(source)) globalDragged=\(globalDragged) localDragged=\(localDragged) draggedAfterPbChange=\(draggedAfterPasteboardChange) pollSamples=\(pollSamples) pollWhilePbChanged=\(pollSamplesWhilePasteboardChanged) pbChanged=\(pasteboardChanged) accessBehaviorDrag=\(dragPasteboard.accessBehavior.rawValue)")
    }
}

// MARK: - U3 / U4: panel that accepts and vends files

final class DropView: NSView, NSDraggingSource {
    var droppedURLs: [URL] = []
    var bookmarks: [Data] = []
    let promiseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("Promises", isDirectory: true)

    override init(frame: NSRect) {
        super.init(frame: frame)
        var types: [NSPasteboard.PasteboardType] = [.fileURL, .URL, .string]
        types += NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        registerForDraggedTypes(types)
        wantsLayer = true
        layer?.backgroundColor = NSColor.systemTeal.withAlphaComponent(0.6).cgColor
        layer?.cornerRadius = 12
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        note("U4 draggingEntered appActive=\(NSApp.isActive) panelKey=\(window?.isKeyWindow ?? false) sourceMask=\(sender.draggingSourceOperationMask.rawValue)")
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        note("U3 drop types=\(pasteboard.types?.map(\.rawValue) ?? []) appActive=\(NSApp.isActive)")

        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if !urls.isEmpty {
            droppedURLs = urls
            bookmarks = []
            for url in urls {
                probe(url, label: "at-drop")
                do {
                    let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
                    bookmarks.append(data)
                    note("U3 security-scoped bookmark created bytes=\(data.count) for \(url.lastPathComponent)")
                } catch {
                    note("U3 security-scoped bookmark FAILED for \(url.lastPathComponent): \(error)")
                }
            }
            for delay in [5.0, 60.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.droppedURLs.forEach { self?.probe($0, label: "after-\(Int(delay))s") }
                    self?.probeBookmarks(label: "after-\(Int(delay))s")
                }
            }
            return true
        }

        let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver] ?? []
        if !receivers.isEmpty {
            try? FileManager.default.createDirectory(at: promiseDirectory, withIntermediateDirectories: true)
            for receiver in receivers {
                receiver.receivePromisedFiles(atDestination: promiseDirectory, options: [:], operationQueue: .main) { url, error in
                    note("U3 promise received \(url.path) error=\(String(describing: error))")
                }
            }
            return true
        }

        if let string = pasteboard.string(forType: .string) {
            note("U3 string dropped length=\(string.count)")
            return true
        }
        return false
    }

    func probe(_ url: URL, label: String) {
        let readable = FileManager.default.isReadableFile(atPath: url.path)
        var firstBytes = "n/a"
        if let handle = try? FileHandle(forReadingFrom: url) {
            firstBytes = "\((try? handle.read(upToCount: 8))?.count ?? -1)B"
            try? handle.close()
        } else {
            firstBytes = "open-failed"
        }
        note("U3 probe[\(label)] \(url.lastPathComponent) readable=\(readable) read=\(firstBytes)")
    }

    func probeBookmarks(label: String) {
        for data in bookmarks {
            var stale = false
            do {
                let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
                let started = url.startAccessingSecurityScopedResource()
                probe(url, label: "\(label)-bookmark(started=\(started),stale=\(stale))")
                if started { url.stopAccessingSecurityScopedResource() }
            } catch {
                note("U3 bookmark resolve FAILED [\(label)]: \(error)")
            }
        }
    }

    // Without this, isMovableByWindowBackground moves the panel instead of starting an item drag.
    override var mouseDownCanMoveWindow: Bool { droppedURLs.isEmpty }

    // The panel is never key while another app is active; let the first click start a drag.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        note("U4 mouseDown appActive=\(NSApp.isActive) panelKey=\(window?.isKeyWindow ?? false) frontmost=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil")")
    }

    // Outbound drag (copy only) to check that dropped references can be vended.
    override func mouseDragged(with event: NSEvent) {
        guard !droppedURLs.isEmpty else { return }
        droppedURLs.forEach { probe($0, label: "before-drag-out") }
        let items = droppedURLs.map { url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            item.setDraggingFrame(NSRect(x: 0, y: 0, width: 64, height: 64), contents: NSWorkspace.shared.icon(forFile: url.path))
            return item
        }
        beginDraggingSession(with: items, event: event, source: self)
        note("U3 drag-out began items=\(items.count)")
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        note("U3 drag-out ended operation=\(operation.rawValue) appActive=\(NSApp.isActive) frontmost=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil")")
    }
}

final class SpikePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let observer = DragObserver()
    var panel: SpikePanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let env = ProcessInfo.processInfo.environment
        note("launch sandboxed=\(env["APP_SANDBOX_CONTAINER_ID"] != nil) home=\(NSHomeDirectory())")
        observer.start()

        let frame = NSRect(x: 900, y: 300, width: 220, height: 160)
        panel = SpikePanel(contentRect: frame, styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView], backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = env["SPIKE_MOVABLE_BG"] == "1"
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = Self.level(named: env["SPIKE_LEVEL"] ?? "floating")
        panel.contentView = DropView(frame: NSRect(origin: .zero, size: frame.size))
        panel.orderFrontRegardless()
        note("U4 panel shown level=\(panel.level.rawValue) behavior=\(panel.collectionBehavior.rawValue) frame=\(NSStringFromRect(panel.frame)) screenHeight=\(NSScreen.screens.first?.frame.height ?? 0)")

        // Control for U3: a path that was never granted must be unreadable inside the sandbox.
        if let control = env["SPIKE_CONTROL_PATH"] {
            (panel.contentView as? DropView)?.probe(URL(fileURLWithPath: control), label: "control-not-granted")
        }

        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self?.reportSpace(reason: "space-changed") }
        }
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("dev.keimvm.ShelfSpike.report"), object: nil, queue: .main) { [weak self] _ in
            self?.reportSpace(reason: "requested")
        }
    }

    func reportSpace(reason: String) {
        let windowID = CGWindowID(panel.windowNumber)
        let onScreen = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? [])
            .first { ($0[kCGWindowNumber as String] as? UInt32) == windowID }
        let layer = onScreen?[kCGWindowLayer as String] as? Int
        note("U4 report(\(reason)) isOnActiveSpace=\(panel.isOnActiveSpace) visible=\(panel.isVisible) occlusionVisible=\(panel.occlusionState.contains(.visible)) cgOnScreen=\(onScreen != nil) cgLayer=\(layer.map(String.init) ?? "nil") frontmost=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil")")
    }

    static func level(named name: String) -> NSWindow.Level {
        switch name {
        case "statusBar": return .statusBar
        case "popUpMenu": return .popUpMenu
        default: return .floating
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
