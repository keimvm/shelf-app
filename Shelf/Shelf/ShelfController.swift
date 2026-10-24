import AppKit
import os

/// The one shelf: shows, hides, and moves its panel, and takes items off it (F4, F6, F7, F14).
///
/// Hiding the shelf keeps its items; only taking them out or removing them does away with them.
@MainActor
final class ShelfController {
    static let size = CGSize(width: 260, height: 200)
    /// How long a generated file outlives its item after it was dragged out. The destination may still
    /// be copying it after the drop.
    static let temporaryFilesGrace: TimeInterval = 30

    let shelf = Shelf()
    let reader: InboundReader
    /// Called after the items change or the shelf is shown or hidden.
    var onChange: (() -> Void)?

    private let storage: TemporaryStorage
    private let log = Logger(subsystem: "dev.keimvm.Shelf", category: "shelf")
    private var panel: ShelfPanel?
    private var viewController: ShelfViewController?
    /// The shelf was emptied while promised files were still arriving; hide it if they leave it empty.
    private var hidesWhenReceivingFinishes = false

    init(storage: TemporaryStorage) {
        self.storage = storage
        reader = InboundReader(storage: storage)
        shelf.onChange = { [weak self] in
            guard let self else { return }
            if viewController?.isViewLoaded == true { viewController?.reload() }
            onChange?()
        }
        reader.onPendingFilesChanged = { [weak self] in
            guard let self, hidesWhenReceivingFinishes else { return }
            hideIfEmpty()
        }
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    /// Shows the shelf centered on `point` (global, bottom-left origin), kept inside that screen. A shelf
    /// already on screen comes over to `point` unless it is under it. The app is not activated (F4).
    func show(near point: CGPoint) {
        let panel = panel ?? makePanel()
        if panel.isVisible, NSMouseInRect(point, panel.frame, false) { return }
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? CGRect(origin: .zero, size: Self.size)
        panel.setFrame(Self.frame(for: Self.size, centeredAt: point, in: visibleFrame), display: true)
        if !panel.isVisible {
            panel.orderFrontRegardless()
            onChange?()
        }
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        onChange?()
    }

    func toggle(near point: CGPoint) {
        isVisible ? hide() : show(near: point)
    }

    /// Puts what `pasteboard` holds on the shelf, showing it near `point` if it is hidden (F13). Returns
    /// whether anything was accepted.
    func put(from pasteboard: NSPasteboard, near point: CGPoint) -> Bool {
        reader.read(pasteboard) { [weak self] items in
            guard let self else { return }
            log.info("Put \(items.count) item(s): \(items.map(\.kindDescription).joined(separator: ","), privacy: .public)")
            shelf.append(items)
            if !isVisible { show(near: point) }
        }
    }

    /// Takes the items at `urls` off the shelf and hides it once it is empty (F7). Their generated files
    /// are deleted after `delay` seconds (F9).
    func remove(_ urls: [URL], keepingFilesFor delay: TimeInterval) {
        let generated = shelf.remove(urls).compactMap { item -> URL? in
            if case .generated(let url, _) = item { url } else { nil }
        }
        if !generated.isEmpty {
            if delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [storage] in
                    generated.forEach(storage.discard)
                }
            } else {
                generated.forEach(storage.discard)
            }
        }
        hideIfEmpty()
    }

    /// Removes every item and hides the shelf.
    func clear() {
        remove(shelf.items.map(\.url), keepingFilesFor: 0)
    }

    /// Whether `point` (global, bottom-left origin) is over the shelf. Used to keep shakes over it from
    /// moving it (F3).
    func contains(_ point: CGPoint) -> Bool {
        guard let panel, panel.isVisible else { return false }
        return NSMouseInRect(point, panel.frame, false)
    }

    /// Hides an empty shelf, waiting for promised files that are still arriving (F7).
    private func hideIfEmpty() {
        guard shelf.items.isEmpty else {
            hidesWhenReceivingFinishes = false
            return
        }
        hidesWhenReceivingFinishes = reader.pendingFileCount > 0
        if !hidesWhenReceivingFinishes { hide() }
    }

    private func makePanel() -> ShelfPanel {
        let panel = ShelfPanel(contentRect: CGRect(origin: .zero, size: Self.size))
        let controller = ShelfViewController(shelf: shelf, reader: reader)
        controller.onHide = { [weak self] in self?.hide() }
        controller.onTakeOut = { [weak self] urls in self?.remove(urls, keepingFilesFor: Self.temporaryFilesGrace) }
        controller.onRemove = { [weak self] urls in self?.remove(urls, keepingFilesFor: 0) }
        panel.contentViewController = controller
        self.panel = panel
        viewController = controller
        return panel
    }

    /// A frame of `size` centered at `point`, shifted as little as needed to fit in `bounds`.
    nonisolated static func frame(for size: CGSize, centeredAt point: CGPoint, in bounds: CGRect) -> CGRect {
        var origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)
        return CGRect(origin: origin, size: size)
    }
}
