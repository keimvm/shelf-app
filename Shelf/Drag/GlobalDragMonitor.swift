import AppKit
import os

/// Watches mouse drags in all apps and reports a shake during an external drag (F2, F3).
///
/// A press counts as an external drag once the drag pasteboard's `changeCount` differs from its
/// value at mouse-down. Presses that begin in this app (our own drags) are ignored. The pasteboard
/// contents are never read here. The mouse is watched only between `start()` and `stop()`, which the
/// app ties to the shake setting (N4).
@MainActor
final class GlobalDragMonitor {
    enum Phase {
        case down, dragged, up
    }

    /// Called with the cursor position (global, bottom-left origin) when a shake completes.
    var onShake: ((CGPoint) -> Void)?

    /// Whether a point is over an existing shelf. Movement there is not counted toward a shake.
    var isOverShelf: ((CGPoint) -> Bool)?

    private struct Press {
        var changeCountAtDown: Int
        var beganInThisApp: Bool
        var isExternalDrag = false
    }

    private let preferences: Preferences
    private let dragChangeCount: () -> Int
    private let log = Logger(subsystem: "dev.keimvm.Shelf", category: "drag")
    private var monitors: [Any] = []
    private var press: Press?
    private var detector = ShakeDetector()

    init(preferences: Preferences, dragChangeCount: (() -> Int)? = nil) {
        self.preferences = preferences
        if let dragChangeCount {
            self.dragChangeCount = dragChangeCount
        } else {
            let pasteboard = NSPasteboard(name: .drag)
            self.dragChangeCount = { pasteboard.changeCount }
        }
    }

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event, inThisApp: false) }
        }) {
            monitors.append(global)
        } else {
            log.error("Global mouse monitor could not be installed")
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event, inThisApp: true) }
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        press = nil
        detector.reset()
    }

    private func handle(_ event: NSEvent, inThisApp: Bool) {
        let phase: Phase
        switch event.type {
        case .leftMouseDown: phase = .down
        case .leftMouseDragged: phase = .dragged
        case .leftMouseUp: phase = .up
        default: return
        }
        // Global events carry screen coordinates; local ones are relative to their window.
        let point = event.window.map { $0.convertPoint(toScreen: event.locationInWindow) } ?? event.locationInWindow
        handle(phase, at: point, time: event.timestamp, inThisApp: inThisApp)
    }

    /// Event handling without `NSEvent`, so it can be driven from tests.
    func handle(_ phase: Phase, at point: CGPoint, time: TimeInterval, inThisApp: Bool) {
        switch phase {
        case .down:
            begin(inThisApp: inThisApp)
        case .dragged:
            // The monitor may have started while the button was already held.
            if press == nil { begin(inThisApp: inThisApp) }
            drag(to: point, time: time)
        case .up:
            if press?.isExternalDrag == true { log.debug("External drag ended") }
            press = nil
            detector.reset()
        }
    }

    private func begin(inThisApp: Bool) {
        press = Press(
            changeCountAtDown: dragChangeCount(),
            beganInThisApp: inThisApp
        )
        detector.reset()
        detector.sensitivity = preferences.shakeSensitivity
    }

    private func drag(to point: CGPoint, time: TimeInterval) {
        guard var press, !press.beganInThisApp else { return }
        if !press.isExternalDrag {
            guard dragChangeCount() != press.changeCountAtDown else { return }
            press.isExternalDrag = true
            self.press = press
            log.debug("External drag began")
        }
        guard isOverShelf?(point) != true, detector.add(point, at: time) else { return }
        log.notice("Shake at (\(point.x, privacy: .public), \(point.y, privacy: .public)) sensitivity=\(self.detector.sensitivity.rawValue, privacy: .public)")
        onShake?(point)
    }
}
