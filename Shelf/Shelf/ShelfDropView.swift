import AppKit

/// Drop target covering a shelf (F5). Highlights while a drop is over it.
final class ShelfDropView: NSView {
    /// Handles a drop. Returns whether anything was accepted.
    var onDrop: ((NSPasteboard) -> Bool)?

    private var isTargeted = false {
        didSet { needsDisplay = true }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes(InboundReader.readableTypes)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let operation = Self.operation(for: sender)
        isTargeted = !operation.isEmpty
        return operation
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        Self.operation(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isTargeted = false
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        isTargeted = false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isTargeted = false
        return onDrop?(sender.draggingPasteboard) ?? false
    }

    /// `.copy` when offered, else `.generic` (Finder offers only that; verification.md K4). Drags that
    /// start in this app are refused (verification.md K3).
    private static func operation(for info: NSDraggingInfo) -> NSDragOperation {
        guard info.draggingSource == nil else { return [] }
        let mask = info.draggingSourceOperationMask
        if mask.contains(.copy) { return .copy }
        if mask.contains(.generic) { return .generic }
        return []
    }

    override func draw(_ dirtyRect: NSRect) {
        guard isTargeted else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 10, yRadius: 10)
        path.lineWidth = 2
        NSColor.controlAccentColor.setStroke()
        path.stroke()
    }
}
