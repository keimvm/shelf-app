// Phase 5 driver: reproduces drags and shakes with synthetic mouse events (CGEvent, global
// top-left coordinates). Requires the invoking process to be trusted for Accessibility. Test code.
//
//   driver shelves [owner]                         print on-screen windows of `owner` (default Shelf)
//   driver drag <fromX> <fromY> <toX> <toY>        press, move, release
//   driver shakedrop <fromX> <fromY> [<atX> <atY>]  drag from a source, shake (at at), drop on the new shelf
//   driver shake <fromX> <fromY> [options]         drag from a source, shake, release back on it;
//                                                  prints which apps opened a window
//       --amp <pt>      swing length (default 120)        --swings <n>  half cycles (default 8)
//       --ms <ms>       one swing's duration (default 75) --angle <deg> 0 = horizontal (default 0)
//       --hz <hz>       event rate (default 120)          --jitter <pt> random off-axis noise
//       --nodrag        move without the button (no drag) --owners a,b  apps to watch (default Shelf)
//       --keep          leave shelves open (default: close every shelf before and after)
//   driver click <x> <y>                           click
//   driver find <bundleID> <title> [window]        print the center of an AX element

import AppKit
import ApplicationServices

func post(_ type: CGEventType, _ point: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
}

func moveLinear(_ type: CGEventType, from: CGPoint, to: CGPoint, steps: Int, stepDelay: useconds_t) {
    for i in 1...max(steps, 1) {
        let t = CGFloat(i) / CGFloat(max(steps, 1))
        post(type, CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
        usleep(stepDelay)
    }
}

struct Window { let owner: String; let id: Int; let frame: CGRect }

func windows(owners: Set<String>) -> [Window] {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    return list.compactMap { info in
        guard let owner = info[kCGWindowOwnerName as String] as? String, owners.contains(owner),
              let id = info[kCGWindowNumber as String] as? Int,
              let bounds = info[kCGWindowBounds as String] as? [String: Any],
              let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
              frame.width > 100, frame.height > 100 else { return nil }
        return Window(owner: owner, id: id, frame: frame)
    }
}

/// Presses at `from` and leaves it slowly so the source app starts its dragging session.
func beginDrag(at from: CGPoint) -> CGPoint {
    post(.mouseMoved, from)
    usleep(200_000)
    post(.leftMouseDown, from)
    usleep(150_000)
    let current = CGPoint(x: from.x + 40, y: from.y)
    moveLinear(.leftMouseDragged, from: from, to: current, steps: 20, stepDelay: 15_000)
    usleep(300_000)
    return current
}

/// Swings back and forth along `angle` with eased (cosine) motion, like a hand.
func swing(_ type: CGEventType, from start: CGPoint, amp: Double, swings: Int, ms: Double, angle: Double, hz: Double, jitter: Double) -> CGPoint {
    let ux = cos(angle * .pi / 180), uy = sin(angle * .pi / 180)
    let steps = max(Int(ms / 1000 * hz), 2)
    let delay = useconds_t(1_000_000 / hz)
    var position = 0.0 // along the axis
    var current = start
    for index in 0..<swings {
        let from = position
        let to = index % 2 == 0 ? amp / 2 : -amp / 2
        let target = index == 0 ? amp / 2 : to
        for step in 1...steps {
            let t = Double(step) / Double(steps)
            let eased = (1 - cos(t * .pi)) / 2
            let along = from + (target - from) * eased
            let noise = jitter > 0 ? Double.random(in: -jitter...jitter) : 0
            current = CGPoint(x: start.x + along * ux - noise * uy, y: start.y + along * uy + noise * ux)
            post(type, current)
            usleep(delay)
        }
        position = target
    }
    return current
}

func closeButton(of window: Window) -> CGPoint { CGPoint(x: window.frame.minX + 17, y: window.frame.minY + 14) }

func click(_ point: CGPoint) {
    post(.mouseMoved, point)
    usleep(100_000)
    post(.leftMouseDown, point)
    usleep(60_000)
    post(.leftMouseUp, point)
    usleep(200_000)
}

/// Clicks the close button of every open shelf until none is left (another app's window may be
/// fading out on top of a button).
func closeAllShelves() {
    for _ in 0..<5 {
        let open = windows(owners: ["Shelf"])
        if open.isEmpty { return }
        usleep(400_000)
        for window in open { click(closeButton(of: window)) }
    }
    if !windows(owners: ["Shelf"]).isEmpty { print("warning: a shelf is still open") }
}

func option(_ name: String, _ fallback: Double) -> Double {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: name), index + 1 < args.count, let value = Double(args[index + 1]) else { return fallback }
    return value
}

func axApp(_ bundleID: String) -> AXUIElement? {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { return nil }
    return AXUIElementCreateApplication(app.processIdentifier)
}

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func findElement(_ element: AXUIElement, title: String, depth: Int = 0) -> AXUIElement? {
    if depth > 20 { return nil }
    for key in [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute, kAXFilenameAttribute] {
        if let text = attribute(element, key as String) as? String, text.contains(title) { return element }
    }
    for child in attribute(element, kAXChildrenAttribute as String) as? [AXUIElement] ?? [] {
        if let found = findElement(child, title: title, depth: depth + 1) { return found }
    }
    return nil
}

let args = CommandLine.arguments
let numbers = args.dropFirst(2).prefix { Double($0) != nil }.prefix(4).compactMap { Double($0) }
switch args.count > 1 ? args[1] : "" {
case "shelves":
    for window in windows(owners: [args.count > 2 ? args[2] : "Shelf"]) {
        print(window.owner, window.id, Int(window.frame.minX), Int(window.frame.minY), Int(window.frame.width), Int(window.frame.height))
    }
case "drag":
    let from = CGPoint(x: numbers[0], y: numbers[1]), to = CGPoint(x: numbers[2], y: numbers[3])
    let current = beginDrag(at: from)
    moveLinear(.leftMouseDragged, from: current, to: to, steps: 40, stepDelay: 15_000)
    usleep(500_000)
    post(.leftMouseUp, to)
    usleep(500_000)
case "shakedrop":
    let owner = "Shelf"
    let before = Set(windows(owners: [owner]).map(\.id))
    let from = CGPoint(x: numbers[0], y: numbers[1])
    var current = beginDrag(at: from)
    if numbers.count == 4 {
        let at = CGPoint(x: numbers[2], y: numbers[3])
        moveLinear(.leftMouseDragged, from: current, to: at, steps: 30, stepDelay: 15_000)
        current = at
        usleep(200_000)
    }
    current = swing(.leftMouseDragged, from: current, amp: 120, swings: 8, ms: 75, angle: 0, hz: 120, jitter: 0)
    usleep(800_000)
    guard let shelf = windows(owners: [owner]).first(where: { !before.contains($0.id) }) else {
        moveLinear(.leftMouseDragged, from: current, to: from, steps: 20, stepDelay: 15_000)
        post(.leftMouseUp, from)
        print("no-shelf"); exit(1)
    }
    let target = CGPoint(x: shelf.frame.midX, y: shelf.frame.midY + 20)
    moveLinear(.leftMouseDragged, from: current, to: target, steps: 30, stepDelay: 15_000)
    usleep(500_000)
    post(.leftMouseUp, target)
    usleep(800_000)
    print(shelf.owner, shelf.id, Int(shelf.frame.minX), Int(shelf.frame.minY), Int(shelf.frame.width), Int(shelf.frame.height))
case "shake":
    let owners = Set((args.firstIndex(of: "--owners").map { args[$0 + 1] } ?? "Shelf").split(separator: ",").map(String.init))
    if !args.contains("--keep") { closeAllShelves() }
    let before = Set(windows(owners: owners).map(\.id))
    let from = CGPoint(x: numbers[0], y: numbers[1])
    let noDrag = args.contains("--nodrag")
    let type: CGEventType = noDrag ? .mouseMoved : .leftMouseDragged
    var current: CGPoint
    if noDrag {
        post(.mouseMoved, from); usleep(200_000); current = from
    } else {
        current = beginDrag(at: from)
    }
    current = swing(type, from: current, amp: option("--amp", 120), swings: Int(option("--swings", 8)), ms: option("--ms", 75),
                    angle: option("--angle", 0), hz: option("--hz", 120), jitter: option("--jitter", 0))
    usleep(600_000)
    let opened = windows(owners: owners).filter { !before.contains($0.id) }
    moveLinear(type, from: current, to: from, steps: 20, stepDelay: 10_000)
    if !noDrag { post(.leftMouseUp, from) }
    usleep(400_000)
    let fired = Set(opened.map(\.owner))
    print(owners.sorted().map { "\($0)=\(fired.contains($0) ? 1 : 0)" }.joined(separator: " "))
    if !args.contains("--keep") { closeAllShelves() }
case "click":
    click(CGPoint(x: numbers[0], y: numbers[1]))
case "find":
    let windowsAX = (axApp(args[2]).flatMap { attribute($0, kAXWindowsAttribute as String) as? [AXUIElement] }) ?? []
    let root = args.count > 4 ? windowsAX.first { ((attribute($0, kAXTitleAttribute as String) as? String) ?? "").contains(args[4]) } : axApp(args[2])
    guard let root, let element = args[3] == "-" ? root : findElement(root, title: args[3]) else { print("not-found"); exit(1) }
    var origin = CGPoint.zero, size = CGSize.zero
    if let p = attribute(element, kAXPositionAttribute as String) { AXValueGetValue(p as! AXValue, .cgPoint, &origin) }
    if let s = attribute(element, kAXSizeAttribute as String) { AXValueGetValue(s as! AXValue, .cgSize, &size) }
    let role = attribute(element, kAXRoleAttribute as String) as? String ?? "?"
    print(Int(origin.x + size.width / 2), Int(origin.y + size.height / 2), "role=\(role)", "origin=\(Int(origin.x)),\(Int(origin.y))", "size=\(Int(size.width))x\(Int(size.height))")
default:
    print("usage: driver shelves|drag|shakedrop|shake|click|find ...")
    exit(2)
}
