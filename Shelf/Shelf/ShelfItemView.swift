import AppKit

/// One shelf item in the collection view: icon and name (F11). Dragging it takes the item out (F6), the ×
/// shown while the pointer is over it takes it off, and a secondary click opens its menu (F14). An item
/// whose original is gone is dimmed and marked "見つかりません" (F10).
final class ShelfItemView: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("ShelfItemView")
    static let size = NSSize(width: 76, height: 84)

    /// Called when a drag starts on this item.
    var onDragOut: ((ShelfItemView, NSEvent) -> Void)?
    /// Makes the menu for a secondary click on this item.
    var onMenu: ((ShelfItemView) -> NSMenu?)?
    /// Called when the × is clicked.
    var onRemove: ((ShelfItemView) -> Void)?

    /// Whether the pointer is over this item, which shows the ×.
    var isHovered = false {
        didSet { removeButton.isHidden = !isHovered }
    }

    private let status = NSTextField(labelWithString: "見つかりません")
    private lazy var removeButton = FirstMouseButton(
        image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "シェルフから外す")!,
        target: self,
        action: #selector(remove(_:))
    )

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

        removeButton.isBordered = false
        removeButton.contentTintColor = .secondaryLabelColor
        removeButton.toolTip = "シェルフから外す"
        removeButton.isHidden = true

        let container = ShelfDragOriginView()
        container.onDragOut = { [weak self] event in
            guard let self else { return }
            onDragOut?(self, event)
        }
        container.onMenu = { [weak self] in
            guard let self else { return nil }
            return onMenu?(self)
        }
        container.passThroughView = removeButton
        for subview in [icon, label, status, removeButton] {
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

            // On the icon's top-left corner.
            removeButton.centerXAnchor.constraint(equalTo: icon.leadingAnchor, constant: 6),
            removeButton.centerYAnchor.constraint(equalTo: icon.topAnchor, constant: 6),
        ])

        view = container
        imageView = icon
        textField = label
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isHovered = false
    }

    @objc private func remove(_ sender: NSButton) {
        onRemove?(self)
    }
}

