import AppKit

/// One shelf item in the collection view: icon and name (F11). Dragging it takes the item out (F6).
/// An item whose original is gone is dimmed and marked "見つかりません" (F10).
final class ShelfItemView: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("ShelfItemView")
    static let size = NSSize(width: 76, height: 84)

    /// Called when a drag starts on this item.
    var onDragOut: ((ShelfItemView, NSEvent) -> Void)?

    private let status = NSTextField(labelWithString: "見つかりません")

    var item: ShelfItem? {
        didSet {
            guard let item else { return }
            imageView?.image = NSWorkspace.shared.icon(forFile: item.url.path)
            imageView?.alphaValue = item.isAvailable ? 1 : 0.35
            textField?.stringValue = item.name
            textField?.textColor = item.isAvailable ? .labelColor : .secondaryLabelColor
            status.isHidden = item.isAvailable
            view.toolTip = item.isAvailable ? item.name : "\(item.name)（見つかりません）"
        }
    }

    override func loadView() {
        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyUpOrDown

        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.alignment = .center
        // One line, keeping the extension visible.
        label.lineBreakMode = .byTruncatingMiddle

        status.font = .systemFont(ofSize: NSFont.smallSystemFontSize - 1)
        status.textColor = .systemRed
        status.alignment = .center
        status.isHidden = true

        let container = ShelfDragOriginView()
        container.onDragOut = { [weak self] event in
            guard let self else { return }
            onDragOut?(self, event)
        }
        for subview in [icon, label, status] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48),

            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 2),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),

            status.topAnchor.constraint(equalTo: label.bottomAnchor),
            status.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            status.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
        ])

        view = container
        imageView = icon
        textField = label
    }
}

