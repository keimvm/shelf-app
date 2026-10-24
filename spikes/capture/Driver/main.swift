// Capture spike driver: invokes a service with NSPerformService, without synthetic input.
// Throwaway code.
//
//   driver <service name> file <path>...   file URLs
//   driver <service name> text <string>    plain text
//   driver <service name> url <url>        a web URL

import AppKit

let args = CommandLine.arguments
guard args.count > 3 else {
    print("usage: driver <service name> file|text|url <value>...")
    exit(2)
}
_ = NSApplication.shared
let pasteboard = NSPasteboard.withUniqueName()
pasteboard.clearContents()
let values = Array(args.dropFirst(3))
switch args[2] {
case "file": pasteboard.writeObjects(values.map { NSURL(fileURLWithPath: $0) })
case "text": pasteboard.setString(values.joined(separator: " "), forType: .string)
case "url": pasteboard.writeObjects([NSURL(string: values[0])!])
default: print("unknown kind \(args[2])"); exit(2)
}
let performed = NSPerformService(args[1], pasteboard)
print("performed=\(performed) types=\(pasteboard.types?.map(\.rawValue) ?? [])")
pasteboard.releaseGlobally()
