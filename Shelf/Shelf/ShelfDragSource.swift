import AppKit

/// Source of one drag out of a shelf (F6). Only `.copy` is offered, so no destination can move an
/// original (N1, verification.md U3). Drops inside this app are not offered at all.
final class ShelfDragSource: NSObject, NSDraggingSource {
    /// The URLs being dragged.
    let urls: [URL]
    /// Called when the session ends with the operation the destination performed (empty if none).
    private let onEnd: (ShelfDragSource, NSDragOperation) -> Void

    init(urls: [URL], onEnd: @escaping (ShelfDragSource, NSDragOperation) -> Void) {
        self.urls = urls
        self.onEnd = onEnd
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        onEnd(self, operation)
    }
}

/// A view that can start a drag out of the shelf.
///
/// Clicks on its subviews go to it. It takes the first click while another app is active
/// (verification.md K2), and starts a drag only from a press it received itself: during an external
/// drag a stray `mouseDragged` can arrive without one (verification.md K3).
final class ShelfDragOriginView: NSView {
    /// Called once per press when the mouse has moved far enough to start a drag.
    var onDragOut: ((NSEvent) -> Void)?

    private var pressLocation: NSPoint?

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        pressLocation = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = pressLocation else { return }
        let distance = hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y)
        guard distance >= 3 else { return }
        pressLocation = nil
        onDragOut?(event)
    }

    override func mouseUp(with event: NSEvent) {
        pressLocation = nil
    }
}
