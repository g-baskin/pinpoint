import AppKit
import PinpointCore

// Before AppDelegate creates the library and settings read their values.
LegacyMigration.run()
let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
