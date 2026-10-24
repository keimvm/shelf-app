import AppKit

/// Floating panel for one shelf (F4).
///
/// Non-activating, so showing or clicking it leaves the drag source app frontmost. It floats above
/// normal windows on every Space, including full-screen ones (verification.md U4). Neither the window
/// background nor the title bar moves the panel; the handle at the top does (verification.md K1, K7).
final class ShelfPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        // Otherwise the transparent title bar moves the panel along with a drag out of the
        // drag-all control in it. `performDrag(with:)` still moves it.
        isMovable = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
    }

    // Lets controls in the panel take clicks; the app still does not activate (verification.md K5).
    override var canBecomeKey: Bool { true }
}
