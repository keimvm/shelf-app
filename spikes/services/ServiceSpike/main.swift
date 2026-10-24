// Services spike: a sandboxed LSUIElement app that provides two services and logs what it receives.
// Throwaway code.
//
//   placeFiles  NSSendFileTypes = public.item. Logs the file URLs, whether they are readable now and
//               after 60s, whether an app-scope bookmark can be made, and the frontmost app.
//   openEmpty   no send types. Logs that it ran.
//
// SPIKE_HOTKEY=1 also registers ⌃⌥⌘N with RegisterEventHotKey, to see which of the two receives it.
// SPIKE_CONTROL_PATH: a file that was never passed to the app, read as a sandbox control.

import AppKit
import Carbon.HIToolbox
import os

let log = Logger(subsystem: "dev.keimvm.ServiceSpike", category: "spike")

func frontmost() -> String { NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil" }

func readable(_ url: URL) -> Bool {
    (try? FileHandle(forReadingFrom: url).readData(ofLength: 1)) != nil || (url.hasDirectoryPath && (try? FileManager.default.contentsOfDirectory(atPath: url.path)) != nil)
}

final class Provider: NSObject {
    var panels: [NSPanel] = []
    /// The most recently activated app other than this one. SPIKE_RESTORE=previous reactivates it.
    var previousApp: NSRunningApplication? = NSWorkspace.shared.frontmostApplication

    override init() {
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app != NSRunningApplication.current else { return }
            self?.previousApp = app
        }
    }

    @objc(placeFiles:userData:error:)
    func placeFiles(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let types = pboard.types?.map(\.rawValue).joined(separator: ",") ?? "nil"
        let urls = pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        log.info("placeFiles types=\(types, privacy: .public) count=\(urls.count) frontmost=\(frontmost(), privacy: .public) isActive=\(NSApp.isActive) pboard=\(pboard.name.rawValue, privacy: .public)")
        for url in urls {
            var bookmark = "fail"
            do {
                let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                bookmark = "\(data.count)"
            } catch {
                bookmark = "error: \(error.localizedDescription)"
            }
            log.info("  url=\(url.path, privacy: .public) readable=\(readable(url)) bookmark=\(bookmark, privacy: .public)")
        }
        showPanel()
        switch ProcessInfo.processInfo.environment["SPIKE_RESTORE"] {
        case "deactivate":
            NSApp.deactivate()
            log.info("deactivated")
        case "previous":
            let activated = previousApp?.activate() ?? false
            log.info("activated previous=\(self.previousApp?.bundleIdentifier ?? "nil", privacy: .public) result=\(activated)")
        default:
            break
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            log.info("after 0.2s frontmost=\(frontmost(), privacy: .public) isActive=\(NSApp.isActive)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            log.info("after 1s frontmost=\(frontmost(), privacy: .public) isActive=\(NSApp.isActive)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            for url in urls {
                log.info("after 60s url=\(url.lastPathComponent, privacy: .public) readable=\(readable(url))")
            }
        }
    }

    @objc(openEmpty:userData:error:)
    func openEmpty(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let types = pboard.types?.map(\.rawValue).joined(separator: ",") ?? "nil"
        log.info("openEmpty types=\(types, privacy: .public) frontmost=\(frontmost(), privacy: .public)")
    }

    func showPanel() {
        let panel = NSPanel(contentRect: NSRect(x: 400, y: 400, width: 200, height: 120),
                            styleMask: [.nonactivatingPanel, .titled, .closable], backing: .buffered, defer: false)
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.title = "ServiceSpike"
        panel.orderFrontRegardless()
        panels.append(panel)
    }
}

final class Delegate: NSObject, NSApplicationDelegate {
    let provider = Provider()
    var hotKey: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = provider
        NSUpdateDynamicServices()
        log.info("launched sandbox=\(ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil) frontmost=\(frontmost(), privacy: .public)")
        if let control = ProcessInfo.processInfo.environment["SPIKE_CONTROL_PATH"] {
            log.info("control readable=\(readable(URL(fileURLWithPath: control)))")
        }
        if ProcessInfo.processInfo.environment["SPIKE_HOTKEY"] == "1" {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                log.info("carbon hotkey pressed frontmost=\(frontmost(), privacy: .public)")
                return noErr
            }, 1, &eventType, nil, nil)
            let status = RegisterEventHotKey(UInt32(kVK_ANSI_N), UInt32(controlKey | optionKey | cmdKey),
                                             EventHotKeyID(signature: 0x5370_6B65, id: 1), GetApplicationEventTarget(), 0, &hotKey)
            log.info("carbon hotkey registered status=\(status)")
        }
    }
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.run()
