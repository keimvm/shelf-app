import AppKit
import os

/// The files selected in Finder, read through Apple Events (F13). Needs the user's permission to
/// automate Finder (System Settings → Privacy & Security → Automation). The files come without a
/// sandbox extension; the read-only file exception lets the app read them (verification.md §5).
enum FinderSelection {
    static let bundleIdentifier = "com.apple.finder"

    private static let log = Logger(subsystem: "dev.keimvm.Shelf", category: "finder")

    /// Whether Finder is the active app.
    @MainActor static var isFinderFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleIdentifier
    }

    /// The selected items, empty when nothing is selected. Nil when Finder could not be asked, for
    /// example without permission.
    @MainActor static func urls() -> [URL]? {
        let script = NSAppleScript(source: """
            with timeout of 2 seconds
                tell application id "\(bundleIdentifier)" to get selection as alias list
            end timeout
            """)
        var error: NSDictionary?
        guard let list = script?.executeAndReturnError(&error) else {
            log.error("Could not read the Finder selection: \(String(describing: error), privacy: .public)")
            return nil
        }
        guard list.numberOfItems > 0 else { return [] }
        return (1...list.numberOfItems).compactMap { list.atIndex($0)?.fileURLValue }
    }

    /// Asks for permission to automate Finder, showing the system prompt the first time. Calls
    /// `completion` on the main actor with whether it is granted.
    static func requestPermission(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        // Blocks while the prompt is shown.
        DispatchQueue.global(qos: .userInitiated).async {
            let target = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
            let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true)
            log.info("Finder automation permission status=\(status)")
            Task { @MainActor in completion(status == noErr) }
        }
    }
}
