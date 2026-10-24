// Service shortcut spike: can a sandboxed app read or change the key equivalent of its own service?
// The system keeps user-chosen service shortcuts in the `pbs` preferences domain (NSServicesStatus).
// Tries to read that domain and to write a harmless probe key into it, then removes the probe.
// Never writes NSServicesStatus itself. Throwaway code.

import AppKit
import os

let log = Logger(subsystem: "dev.keimvm.PrefsSpike", category: "spike")
let domain = "pbs" as CFString
let probeKey = "PrefsSpikeProbe" as CFString

log.info("sandbox=\(ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil)")

let status = CFPreferencesCopyAppValue("NSServicesStatus" as CFString, domain)
log.info("read NSServicesStatus: \(status == nil ? "nil" : "\(CFGetTypeID(status!) == CFDictionaryGetTypeID() ? "dictionary" : "other")", privacy: .public)")
let keys = CFPreferencesCopyKeyList(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String]
log.info("key list: \(keys?.joined(separator: ",") ?? "nil", privacy: .public)")

CFPreferencesSetAppValue(probeKey, "1" as CFString, domain)
let synced = CFPreferencesAppSynchronize(domain)
let readBack = CFPreferencesCopyAppValue(probeKey, domain) as? String
log.info("write probe: synchronize=\(synced) readBack=\(readBack ?? "nil", privacy: .public)")

CFPreferencesSetAppValue(probeKey, nil, domain)
log.info("remove probe: synchronize=\(CFPreferencesAppSynchronize(domain))")

let settingsURLs = [
    "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts",
    "x-apple.systempreferences:com.apple.Keyboard-Settings.extension",
]
for string in settingsURLs {
    let handler = NSWorkspace.shared.urlForApplication(toOpen: URL(string: string)!)
    log.info("url \(string, privacy: .public) handler=\(handler?.lastPathComponent ?? "nil", privacy: .public)")
}
exit(0)
