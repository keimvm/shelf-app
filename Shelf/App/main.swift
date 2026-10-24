import AppKit

// No main nib: the app has no windows of its own until a shelf is opened.
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
