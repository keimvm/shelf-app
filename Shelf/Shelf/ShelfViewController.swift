import AppKit
import os

/// Content of the shelf panel: a handle bar with a hide button and a drag-all control above the item
/// grid. The whole panel accepts drops (F5); items are dragged out one at a time or all at once (F6).
/// Each item has a × and a menu to take it off, and the menus can empty the shelf (F14).
final class ShelfViewController: NSViewController, NSCollectionViewDataSource {
    static let handleHeight: CGFloat = 28

    /// Called when the hide button is clicked.
    var onHide: (() -> Void)?
    /// Called with the URLs a destination took in a drag out (F6).
    var onTakeOut: (([URL]) -> Void)?
    /// Called with the URLs the user took off with the × or a menu (F14).
    var onRemove: (([URL]) -> Void)?
    /// Called when the user empties the shelf through a menu (F14).
    var onClear: (() -> Void)?

    private let shelf: Shelf
    private let reader: InboundReader
    private let log = Logger(subsystem: "dev.keimvm.Shelf", category: "shelf")
    private let collectionView = NSCollectionView()
    private let hint = NSTextField(labelWithString: "ここにドロップ")
    private let dragAll = ShelfDragOriginView()
    private let dragAllCount = NSTextField(labelWithString: "")
    /// The drag in progress, kept alive until it ends.
    private var dragSource: ShelfDragSource?

    init(shelf: Shelf, reader: InboundReader) {
        self.shelf = shelf
        self.reader = reader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func loadView() {
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active

        let dropView = ShelfDropView()
        dropView.onDrop = { [reader, shelf, log] pasteboard in
            reader.read(pasteboard) { items in
                log.info("Received \(items.count) item(s): \(items.map(\.kindDescription).joined(separator: ","), privacy: .public)")
                shelf.append(items)
            }
        }

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = ShelfItemView.size
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 4
        layout.sectionInset = NSEdgeInsets(top: 4, left: 8, bottom: 8, right: 8)
        collectionView.collectionViewLayout = layout
        collectionView.backgroundColors = [.clear]
        collectionView.register(ShelfItemView.self, forItemWithIdentifier: ShelfItemView.identifier)
        collectionView.dataSource = self

        let scrollView = NSScrollView()
        scrollView.documentView = collectionView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let handle = ShelfHandleView()
        // Hiding keeps the items, so the button does not look like closing for good.
        let hideButton = FirstMouseButton(
            image: NSImage(systemSymbolName: "minus.circle.fill", accessibilityDescription: "隠す")!,
            target: self,
            action: #selector(hide(_:))
        )
        hideButton.isBordered = false
        hideButton.contentTintColor = .secondaryLabelColor
        hideButton.toolTip = "隠す（項目は残ります）"

        hint.textColor = .secondaryLabelColor
        hint.alignment = .center

        let dragAllIcon = NSImageView(image: NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)!)
        dragAllIcon.contentTintColor = .secondaryLabelColor
        dragAllIcon.setAccessibilityElement(false)
        dragAllCount.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        dragAllCount.textColor = .secondaryLabelColor
        dragAll.toolTip = "すべての項目をドラッグ"
        dragAll.setAccessibilityElement(true)
        dragAll.setAccessibilityRole(.group)
        dragAll.setAccessibilityLabel("すべての項目をドラッグ")
        dragAll.onDragOut = { [weak self, dragAll] event in
            guard let self else { return }
            shelf.refreshFiles()
            let center = NSPoint(x: dragAll.bounds.midX, y: dragAll.bounds.midY)
            beginDragOut(shelf.items, from: dragAll.convert(Self.iconFrame(centeredAt: center), to: view), event: event)
        }
        for subview in [dragAllIcon, dragAllCount] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            dragAll.addSubview(subview)
        }

        for subview in [dropView, handle, hideButton, dragAll] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            background.addSubview(subview)
        }
        for subview in [scrollView, hint] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            dropView.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            dropView.topAnchor.constraint(equalTo: background.topAnchor),
            dropView.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            dropView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            dropView.trailingAnchor.constraint(equalTo: background.trailingAnchor),

            handle.topAnchor.constraint(equalTo: background.topAnchor),
            handle.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            handle.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            handle.heightAnchor.constraint(equalToConstant: Self.handleHeight),

            hideButton.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 8),
            hideButton.centerYAnchor.constraint(equalTo: handle.centerYAnchor),

            dragAll.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -6),
            dragAll.topAnchor.constraint(equalTo: handle.topAnchor, constant: 4),
            dragAll.bottomAnchor.constraint(equalTo: handle.bottomAnchor, constant: -4),
            dragAllIcon.leadingAnchor.constraint(equalTo: dragAll.leadingAnchor, constant: 4),
            dragAllIcon.centerYAnchor.constraint(equalTo: dragAll.centerYAnchor),
            dragAllCount.leadingAnchor.constraint(equalTo: dragAllIcon.trailingAnchor, constant: 2),
            dragAllCount.trailingAnchor.constraint(equalTo: dragAll.trailingAnchor, constant: -4),
            dragAllCount.centerYAnchor.constraint(equalTo: dragAll.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: dropView.topAnchor, constant: Self.handleHeight),
            scrollView.bottomAnchor.constraint(equalTo: dropView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: dropView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: dropView.trailingAnchor),

            hint.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            hint.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
        // Secondary clicks outside the items come up to here.
        background.menu = makeShelfMenu()
        view = background
        // Originals may have moved since the last look; check when the pointer comes over the shelf (F10).
        // Moves show the × of the item under the pointer.
        background.addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self))

        reload()
    }

    override func mouseEntered(with event: NSEvent) {
        shelf.refreshFiles()
        updateHover()
    }

    override func mouseMoved(with event: NSEvent) {
        updateHover()
    }

    override func mouseExited(with event: NSEvent) {
        updateHover()
    }

    /// Shows the shelf's current items.
    func reload() {
        hint.isHidden = !shelf.items.isEmpty
        let available = shelf.items.filter(\.isAvailable).count
        dragAll.isHidden = available == 0
        dragAllCount.stringValue = "\(available)"
        collectionView.reloadData()
        // The pointer may now be over another item, as after clicking a × (the next item takes its place).
        collectionView.layoutSubtreeIfNeeded()
        updateHover()
    }

    /// Marks the item under the pointer as hovered and the others not.
    private func updateHover() {
        guard let window = view.window else { return }
        let point = collectionView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let hovered = collectionView.visibleRect.contains(point) ? collectionView.indexPathForItem(at: point) : nil
        for indexPath in collectionView.indexPathsForVisibleItems() {
            (collectionView.item(at: indexPath) as? ShelfItemView)?.isHovered = indexPath == hovered
        }
    }

    private func dragOut(from itemView: ShelfItemView, event: NSEvent) {
        guard let index = collectionView.indexPath(for: itemView)?.item, let imageView = itemView.imageView else { return }
        let frame = imageView.convert(imageView.bounds, to: view)
        // Refreshing keeps the order, so the index still points at the same item.
        shelf.refreshFiles()
        beginDragOut([shelf.items[index]], from: frame, event: event)
    }

    /// Starts dragging the available `items` out, `.copy` only (F6). Missing originals stay (F10).
    /// `frame` is where the drag image starts, in the root view.
    private func beginDragOut(_ items: [ShelfItem], from frame: NSRect, event: NSEvent) {
        let available = items.filter(\.isAvailable)
        guard !available.isEmpty else { return }
        let draggingItems = available.enumerated().map { index, item in
            let draggingItem = NSDraggingItem(pasteboardWriter: item.url as NSURL)
            let offset = CGFloat(min(index, 4)) * 4
            draggingItem.setDraggingFrame(frame.offsetBy(dx: offset, dy: -offset), contents: NSWorkspace.shared.icon(forFile: item.url.path))
            return draggingItem
        }
        let source = ShelfDragSource(urls: available.map(\.url)) { [weak self] source, operation in
            self?.dragOutEnded(source, operation: operation)
        }
        dragSource = source
        view.beginDraggingSession(with: draggingItems, event: event, source: source)
        log.info("Drag out began with \(available.count) item(s): \(available.map(\.kindDescription).joined(separator: ","), privacy: .public)")
    }

    /// Takes the dragged items off the shelf when the destination accepted them (F6, F7).
    private func dragOutEnded(_ source: ShelfDragSource, operation: NSDragOperation) {
        dragSource = nil
        log.info("Drag out ended with operation \(operation.rawValue)")
        guard !operation.isEmpty else { return }
        onTakeOut?(source.urls)
    }

    /// Takes the item of `itemView` off (F14).
    private func remove(_ itemView: ShelfItemView) {
        guard let index = collectionView.indexPath(for: itemView)?.item, shelf.items.indices.contains(index) else { return }
        onRemove?([shelf.items[index].url])
    }

    /// The menu of one item (F14). A missing original cannot be shown in Finder.
    private func menu(for itemView: ShelfItemView) -> NSMenu? {
        guard let index = collectionView.indexPath(for: itemView)?.item, shelf.items.indices.contains(index) else { return nil }
        let item = shelf.items[index]
        let menu = NSMenu()
        let reveal = ActionMenuItem(title: "Finder に表示") {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }
        reveal.isEnabled = item.isAvailable
        menu.autoenablesItems = false
        menu.addItem(reveal)
        menu.addItem(ActionMenuItem(title: "シェルフから外す") { [weak self] in self?.onRemove?([item.url]) })
        menu.addItem(.separator())
        menu.addItem(makeClearItem())
        return menu
    }

    /// The menu of the shelf outside its items (F14).
    private func makeShelfMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        menu.addItem(makeClearItem())
        return menu
    }

    private func makeClearItem() -> NSMenuItem {
        let item = ActionMenuItem(title: "シェルフを空にする") { [weak self] in self?.onClear?() }
        item.isEnabled = !shelf.items.isEmpty
        return item
    }

    private static func iconFrame(centeredAt center: NSPoint) -> NSRect {
        NSRect(x: center.x - 24, y: center.y - 24, width: 48, height: 48)
    }

    @objc private func hide(_ sender: NSButton) {
        onHide?()
    }

    // MARK: NSCollectionViewDataSource

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        shelf.items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let view = collectionView.makeItem(withIdentifier: ShelfItemView.identifier, for: indexPath)
        if let itemView = view as? ShelfItemView {
            itemView.item = shelf.items[indexPath.item]
            itemView.onDragOut = { [weak self] itemView, event in self?.dragOut(from: itemView, event: event) }
            itemView.onMenu = { [weak self] itemView in self?.menu(for: itemView) }
            itemView.onRemove = { [weak self] itemView in self?.remove(itemView) }
        }
        return view
    }
}

extension ShelfViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items.forEach { $0.isEnabled = !shelf.items.isEmpty }
    }
}

/// Top strip that moves the panel. A grip is drawn in the middle.
private final class ShelfHandleView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        let grip = NSRect(x: bounds.midX - 18, y: bounds.midY - 2, width: 36, height: 4)
        NSColor.tertiaryLabelColor.setFill()
        NSBezierPath(roundedRect: grip, xRadius: 2, yRadius: 2).fill()
    }
}

/// The panel is usually not key while another app is active; take the first click anyway (verification.md K2).
final class FirstMouseButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// A menu item that runs a closure.
private final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run(_:)), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    @objc private func run(_ sender: NSMenuItem) {
        handler()
    }
}
