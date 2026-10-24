// Phase 0 driver: reproduces drags with synthetic mouse events (CGEvent, global top-left coordinates).
// Requires the invoking process to be trusted for Accessibility. Throwaway code.
//
//   driver drag <fromX> <fromY> <toX> <toY> [shake]   press, (shake), move, release
//   driver find <bundleID> <title>                    print the center of an AX element (e.g. a Finder icon)
//   driver fullscreen <bundleID> <0|1>                toggle AXFullScreen on the app's focused window

import AppKit
import ApplicationServices

func post(_ type: CGEventType, _ point: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
}

func dragMove(from: CGPoint, to: CGPoint, steps: Int, stepDelay: useconds_t) {
    for i in 1...steps {
        let t = CGFloat(i) / CGFloat(steps)
        post(.leftMouseDragged, CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
        usleep(stepDelay)
    }
}

func drag(from: CGPoint, to: CGPoint, shake: Bool) {
    post(.mouseMoved, from)
    usleep(200_000)
    post(.leftMouseDown, from)
    usleep(150_000)
    // Leave the source slowly so the source app starts its dragging session.
    var current = CGPoint(x: from.x + 40, y: from.y)
    dragMove(from: from, to: current, steps: 20, stepDelay: 15_000)
    usleep(300_000)
    if shake {
        // Four left/right swings of 120pt in about 0.6s.
        for swing in 0..<8 {
            let next = CGPoint(x: current.x + (swing % 2 == 0 ? 120 : -120), y: current.y)
            dragMove(from: current, to: next, steps: 6, stepDelay: 12_000)
            current = next
        }
        usleep(800_000)
    }
    dragMove(from: current, to: to, steps: 40, stepDelay: 15_000)
    usleep(500_000)
    post(.leftMouseUp, to)
    usleep(500_000)
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
    if depth > 14 { return nil }
    for key in [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute, kAXFilenameAttribute] {
        if (attribute(element, key as String) as? String) == title { return element }
    }
    for child in attribute(element, kAXChildrenAttribute as String) as? [AXUIElement] ?? [] {
        if let found = findElement(child, title: title, depth: depth + 1) { return found }
    }
    return nil
}

func center(_ element: AXUIElement) -> CGPoint? {
    guard let posValue = attribute(element, kAXPositionAttribute as String),
          let sizeValue = attribute(element, kAXSizeAttribute as String) else { return nil }
    var position = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(posValue as! AXValue, .cgPoint, &position)
    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
    return CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
}

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "drag":
    let n = args[2...5].compactMap { Double($0) }
    drag(from: CGPoint(x: n[0], y: n[1]), to: CGPoint(x: n[2], y: n[3]), shake: args.count > 6 && args[6] == "shake")
case "find":
    // Optional 5th argument restricts the search to the window with that title.
    let windows = (axApp(args[2]).flatMap { attribute($0, kAXWindowsAttribute as String) as? [AXUIElement] }) ?? []
    let root = args.count > 4 ? windows.first { (attribute($0, kAXTitleAttribute as String) as? String) == args[4] } : axApp(args[2])
    guard let root, let element = args[3] == "-" ? root : findElement(root, title: args[3]), let point = center(element) else {
        print("not-found"); exit(1)
    }
    let role = attribute(element, kAXRoleAttribute as String) as? String ?? "?"
    var origin = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(attribute(element, kAXPositionAttribute as String) as! AXValue, .cgPoint, &origin)
    AXValueGetValue(attribute(element, kAXSizeAttribute as String) as! AXValue, .cgSize, &size)
    print("\(Int(point.x)) \(Int(point.y)) role=\(role) origin=\(Int(origin.x)),\(Int(origin.y)) size=\(Int(size.width))x\(Int(size.height))")
case "fullscreen":
    guard let app = axApp(args[2]), let window = attribute(app, kAXFocusedWindowAttribute as String) else {
        print("no-window"); exit(1)
    }
    let result = AXUIElementSetAttributeValue(window as! AXUIElement, "AXFullScreen" as CFString, (args[3] == "1") as CFBoolean)
    print("AXFullScreen set: \(result.rawValue)")
default:
    print("usage: driver drag|find|fullscreen ...")
    exit(2)
}
