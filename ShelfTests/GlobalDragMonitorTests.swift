import CoreGraphics
import Foundation
import Testing
@testable import Shelf

@MainActor
struct GlobalDragMonitorTests {
    private final class FakeDragPasteboard {
        var changeCount = 10
    }

    private let pasteboard = FakeDragPasteboard()
    private let preferences = Preferences(defaults: UserDefaults(suiteName: "ShelfTests.\(UUID().uuidString)")!)

    private func makeMonitor() -> (GlobalDragMonitor, shakes: () -> [CGPoint]) {
        let pasteboard = pasteboard
        let monitor = GlobalDragMonitor(preferences: preferences, dragChangeCount: { pasteboard.changeCount })
        var shakes: [CGPoint] = []
        monitor.onShake = { shakes.append($0) }
        return (monitor, { shakes })
    }

    /// Mouse-down, then a horizontal zigzag with enough reversals for the standard sensitivity.
    /// `changePasteboardAfter` drag samples into the press, the drag pasteboard changes.
    private func press(
        _ monitor: GlobalDragMonitor,
        inThisApp: Bool = false,
        changePasteboardAfter: Int? = 2,
        release: Bool = true
    ) {
        monitor.handle(.down, at: CGPoint(x: 500, y: 500), time: 0, inThisApp: inThisApp)
        var x: CGFloat = 500
        var time: TimeInterval = 0
        var sample = 0
        for stroke in 0..<8 {
            let sign: CGFloat = stroke.isMultiple(of: 2) ? 1 : -1
            for _ in 0..<8 {
                if sample == changePasteboardAfter { pasteboard.changeCount += 1 }
                sample += 1
                x += sign * 10
                time += 0.01
                monitor.handle(.dragged, at: CGPoint(x: x, y: 500), time: time, inThisApp: inThisApp)
            }
        }
        if release {
            monitor.handle(.up, at: CGPoint(x: x, y: 500), time: time, inThisApp: inThisApp)
        }
    }

    @Test func shakeDuringExternalDragFiresOnce() {
        let (monitor, shakes) = makeMonitor()
        press(monitor)
        #expect(shakes().count == 1)
    }

    @Test func shakeWithoutDragPasteboardChangeIsIgnored() {
        // e.g. moving a window or selecting a range
        let (monitor, shakes) = makeMonitor()
        press(monitor, changePasteboardAfter: nil)
        #expect(shakes().isEmpty)
    }

    @Test func dragStartedInThisAppIsIgnored() {
        let (monitor, shakes) = makeMonitor()
        press(monitor, inThisApp: true)
        #expect(shakes().isEmpty)
    }

    @Test func eachDragCanFireAgain() {
        let (monitor, shakes) = makeMonitor()
        press(monitor)
        press(monitor)
        #expect(shakes().count == 2)
    }

    @Test func pasteboardChangeBeforeMouseDownDoesNotCount() {
        let (monitor, shakes) = makeMonitor()
        pasteboard.changeCount += 5
        press(monitor, changePasteboardAfter: nil)
        #expect(shakes().isEmpty)
    }

    @Test func shakeOverExistingShelfIsIgnored() {
        let (monitor, shakes) = makeMonitor()
        monitor.isOverShelf = { _ in true }
        press(monitor)
        #expect(shakes().isEmpty)
    }

    @Test func sensitivityIsReadAtMouseDown() {
        // Three short reversals fire at the highest sensitivity but not at the standard one.
        preferences.shakeSensitivity = .highest
        let (monitor, shakes) = makeMonitor()
        monitor.handle(.down, at: CGPoint(x: 500, y: 500), time: 0, inThisApp: false)
        pasteboard.changeCount += 1
        let xs: [CGFloat] = [520, 540, 560, 540, 520, 500, 520, 540, 520]
        for (i, x) in xs.enumerated() {
            monitor.handle(.dragged, at: CGPoint(x: x, y: 500), time: Double(i + 1) * 0.02, inThisApp: false)
        }
        #expect(shakes().count == 1)
    }
}
