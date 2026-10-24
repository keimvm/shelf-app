// Capture spike: a sandboxed LSUIElement app with ONE service that declares both file types
// (NSSendFileTypes) and text/URL types (NSSendTypes). Logs what arrives. Throwaway code.
//
// Questions: does a single service receive files, text and URLs; are received files readable and
// can they get a security-scoped bookmark; which app is frontmost while the handler runs.
// SPIKE_CONTROL_PATH: a file that was never passed to the app, read as a sandbox control.

import AppKit
import os

let log = Logger(subsystem: "dev.keimvm.CaptureSpike", category: "spike")

func frontmost() -> String { NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil" }

func readable(_ url: URL) -> Bool {
    (try? FileHandle(forReadingFrom: url).readData(ofLength: 1)) != nil
}

final class Provider: NSObject {
    @objc(put:userData:error:)
    func put(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let types = pboard.types?.map(\.rawValue).joined(separator: ",") ?? "nil"
        let files = pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        let urls = (pboard.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []).filter { !$0.isFileURL }
        let text = pboard.string(forType: .string)
        log.info("put types=\(types, privacy: .public) files=\(files.count) urls=\(urls.map(\.absoluteString), privacy: .public) textLength=\(text?.count ?? -1) frontmost=\(frontmost(), privacy: .public) isActive=\(NSApp.isActive)")
        for url in files {
            let bookmark: String
            do {
                bookmark = "\(try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil).count)"
            } catch {
                bookmark = "error: \(error.localizedDescription)"
            }
            log.info("  file=\(url.lastPathComponent, privacy: .public) readable=\(readable(url)) bookmark=\(bookmark, privacy: .public)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            log.info("after 0.3s frontmost=\(frontmost(), privacy: .public) isActive=\(NSApp.isActive)")
        }
    }
}

final class Delegate: NSObject, NSApplicationDelegate {
    let provider = Provider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = provider
        NSUpdateDynamicServices()
        log.info("launched sandbox=\(ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil)")
        if let control = ProcessInfo.processInfo.environment["SPIKE_CONTROL_PATH"] {
            log.info("control readable=\(readable(URL(fileURLWithPath: control)))")
        }
    }
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.run()
