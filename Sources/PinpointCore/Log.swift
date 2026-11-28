import os

public enum PinpointLog {
    // Must match CFBundleIdentifier in Resources/Info.plist: the README's `log show` command filters on it.
    public static let subsystem = "app.pinpoint.Pinpoint"
    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let capture = Logger(subsystem: subsystem, category: "capture")
    public static let ai = Logger(subsystem: subsystem, category: "ai")
    public static let storage = Logger(subsystem: subsystem, category: "storage")
    public static let account = Logger(subsystem: subsystem, category: "account")
}
