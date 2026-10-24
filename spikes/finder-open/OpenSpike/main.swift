// Finder-open spike: a sandboxed LSUIElement app that declares no document types and logs the files
// it is asked to open (Finder: `open selection using <this app>`). Throwaway code.
//
// SPIKE_CONTROL_PATH: a file that was never passed to the app, read as a sandbox control.

import AppKit
import os

let log = Logger(subsystem: "dev.keimvm.OpenSpike", category: "spike")

func frontmost() -> String { NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil" }

func readable(_ url: URL) -> Bool {
    if url.hasDirectoryPath { return (try? FileManager.default.contentsOfDirectory(atPath: url.path)) != nil }
    return (try? FileHandle(forReadingFrom: url).readData(ofLength: 1)) != nil
}

final class Delegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("launched sandbox=\(ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil) frontmost=\(frontmost(), privacy: .public)")
        if let control = ProcessInfo.processInfo.environment["SPIKE_CONTROL_PATH"] {
            let url = URL(fileURLWithPath: control)
            var bookmark = "ok"
            do { _ = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) } catch { bookmark = "\(error)" }
            log.info("control readable=\(readable(url)) exists=\(FileManager.default.fileExists(atPath: url.path)) bookmark=\(bookmark, privacy: .public)")
            // A plain bookmark, then follow a rename with it (SPIKE_RENAME_TO is renamed by the driver).
            if let plain = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                log.info("plain bookmark=\(plain.count)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    for options: URL.BookmarkResolutionOptions in [[.withoutUI], [.withSecurityScope, .withoutUI]] {
                        var stale = false
                        let resolved = try? URL(resolvingBookmarkData: plain, options: options, relativeTo: nil, bookmarkDataIsStale: &stale)
                        log.info("resolve options=\(options.rawValue) -> \(resolved?.path ?? "nil", privacy: .public) stale=\(stale) readable=\(resolved.map(readable) ?? false)")
                    }
                }
            } else {
                log.info("plain bookmark failed")
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        log.info("open count=\(urls.count) frontmost=\(frontmost(), privacy: .public) isActive=\(NSApp.isActive)")
        for url in urls {
            let bookmark = (try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil))?.count ?? -1
            log.info("  url=\(url.path, privacy: .public) readable=\(readable(url)) bookmark=\(bookmark)")
        }
        for delay in [0.3, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                log.info("after \(delay)s frontmost=\(frontmost(), privacy: .public) isActive=\(NSApp.isActive)")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            for url in urls {
                log.info("after 60s url=\(url.lastPathComponent, privacy: .public) readable=\(readable(url))")
            }
        }
    }
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.run()
