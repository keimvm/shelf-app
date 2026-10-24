import AppKit

/// A small panel that asks for a shortcut. The key combinations pressed while it is open replace the shown one.
///
/// The app cannot count on being activated from the menu bar item (`NSApp.activate()` there was refused), so
/// the panel is non-activating and becomes key instead, which still brings it the keys.
@MainActor
final class HotKeyRecorder: NSObject, NSWindowDelegate {
    /// Applies the chosen combination (nil for none). Returning false keeps the panel open with an error.
    var onCommit: ((HotKey?) -> Bool)?
    var onClose: (() -> Void)?

    private let panel: NSPanel
    private let field: RecorderField
    private let messageLabel: NSTextField
    private static let message = "使うキーの組み合わせを押してください。⌃・⌥・⌘ のどれかを含めます（F1〜F20 は単独でも使えます）。"

    init(title: String, hotKey: HotKey?) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        field = RecorderField(hotKey: hotKey)
        messageLabel = NSTextField(wrappingLabelWithString: Self.message)
        super.init()

        panel.title = title
        panel.level = .modalPanel
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        messageLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        messageLabel.preferredMaxLayoutWidth = 280

        let noneButton = NSButton(title: "なしにする", target: self, action: #selector(clear(_:)))
        let cancelButton = NSButton(title: "キャンセル", target: self, action: #selector(cancel(_:)))
        cancelButton.keyEquivalent = "\u{1b}"
        let okButton = NSButton(title: "OK", target: self, action: #selector(commit(_:)))
        okButton.keyEquivalent = "\r"
        let buttons = NSStackView(views: [noneButton, NSView(), cancelButton, okButton])

        let stack = NSStackView(views: [messageLabel, field, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = stack
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalToConstant: 320),
            field.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40),
            field.heightAnchor.constraint(equalToConstant: 32),
            buttons.widthAnchor.constraint(equalTo: field.widthAnchor),
        ])
        panel.initialFirstResponder = field
    }

    func show() {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // The owner usually lets go of the recorder in `onClose`.
        withExtendedLifetime(self) { onClose?() }
    }

    @objc private func commit(_ sender: NSButton) {
        apply(field.hotKey)
    }

    @objc private func clear(_ sender: NSButton) {
        apply(nil)
    }

    @objc private func cancel(_ sender: NSButton) {
        panel.close()
    }

    private func apply(_ hotKey: HotKey?) {
        if onCommit?(hotKey) ?? true {
            panel.close()
        } else {
            messageLabel.stringValue = "\(hotKey?.displayName ?? "") は使えません。ほかのアプリが使っている可能性があります。別の組み合わせを押してください。"
            messageLabel.textColor = .systemRed
        }
    }
}

/// Shows a shortcut and records the next one pressed. Combinations `HotKey(event:)` rejects, such as a
/// plain Return or Escape, are left to the panel's buttons.
private final class RecorderField: NSView {
    private(set) var hotKey: HotKey? {
        didSet { label.stringValue = hotKey?.displayName ?? "なし" }
    }
    private let label = NSTextField(labelWithString: "")

    init(hotKey: HotKey?) {
        self.hotKey = hotKey
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1

        label.stringValue = hotKey?.displayName ?? "なし"
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func updateLayer() {
        layer?.borderColor = NSColor.keyboardFocusIndicatorColor.cgColor
    }

    // Combinations with ⌘ or ⌃ arrive here first; the others come to `keyDown`.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        record(event) || super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if !record(event) {
            super.keyDown(with: event)
        }
    }

    private func record(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, let hotKey = HotKey(event: event) else { return false }
        self.hotKey = hotKey
        return true
    }
}
