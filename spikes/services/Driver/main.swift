// Services spike driver: synthetic key presses (CGEvent). Requires the invoking process to be trusted
// for Accessibility. Throwaway code.
//
//   driver key <keyCode> [ctrl] [opt] [cmd] [shift] [fn]   press and release one key with modifiers

import ApplicationServices
import Foundation

let args = CommandLine.arguments
guard args.count > 2, args[1] == "key", let keyCode = CGKeyCode(args[2]) else {
    print("usage: driver key <keyCode> [ctrl] [opt] [cmd] [shift] [fn]")
    exit(2)
}
var flags: CGEventFlags = []
for name in args.dropFirst(3) {
    switch name {
    case "ctrl": flags.insert(.maskControl)
    case "opt": flags.insert(.maskAlternate)
    case "cmd": flags.insert(.maskCommand)
    case "shift": flags.insert(.maskShift)
    case "fn": flags.insert(.maskSecondaryFn)
    default: print("unknown modifier \(name)"); exit(2)
    }
}
for down in [true, false] {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down)
    event?.flags = flags
    event?.post(tap: .cghidEventTap)
    usleep(50_000)
}
print("trusted=\(AXIsProcessTrusted())")
