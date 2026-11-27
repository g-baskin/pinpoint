import AppKit
import CoreAudio
import Foundation

/// Dictation apps that type into the focused text field (Pinpoint just keeps the note box focused for them).
struct ExternalDictation: Equatable {
    let name: String
    let bundleID: String
    /// e.g. "Hold Left ⌥ Option to talk"
    let hint: String
    /// The app's push-to-talk uses ⌥, so Pinpoint must not also listen on ⌥.
    let usesOption: Bool

    static let known: [(String, String)] = [
        ("com.electron.wispr-flow", "Wispr Flow"),
        ("com.superduper.superwhisper", "Superwhisper"),
        ("com.electron.aqua-voice", "Aqua Voice"),
        ("com.prakashjoshipax.VoiceInk", "VoiceInk"),
        ("com.goodsnooze.MacWhisper", "MacWhisper"),
    ]

    /// The first known dictation app that's running right now.
    static func running() -> ExternalDictation? {
        let apps = NSWorkspace.shared.runningApplications
        for (id, name) in known where apps.contains(where: { $0.bundleIdentifier == id }) {
            if id == "com.electron.wispr-flow", let key = wisprPushToTalk() {
                return ExternalDictation(name: name, bundleID: id, hint: "Hold \(key.label) to talk (\(name))", usesOption: key.usesOption)
            }
            return ExternalDictation(name: name, bundleID: id, hint: "Use your \(name) shortcut to talk", usesOption: false)
        }
        return nil
    }

    static let keyNames: [Int: String] = [58: "Left ⌥ Option", 61: "Right ⌥ Option", 63: "fn", 59: "Left ⌃ Control", 62: "Right ⌃ Control",
                                         55: "Left ⌘ Command", 54: "Right ⌘ Command", 56: "Left ⇧ Shift", 60: "Right ⇧ Shift",
                                         49: "Space", 57: "Caps Lock", 48: "Tab"]

    /// Reads Wispr Flow's push-to-talk shortcut from its settings file (read-only).
    static func wisprPushToTalk() -> (label: String, usesOption: Bool)? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Wispr Flow/config.json")
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let prefs = root["prefs"] as? [String: Any], let user = prefs["user"] as? [String: Any],
              let shortcuts = user["shortcuts"] as? [String: String],
              let combo = shortcuts.first(where: { $0.value == "ptt" })?.key else { return ("Wispr Flow's shortcut", false) }
        let codes = combo.split(separator: "+").compactMap { Int($0) }
        let label = codes.map { keyNames[$0] ?? "key \($0)" }.joined(separator: " + ")
        return (label, codes.contains(58) || codes.contains(61))
    }
}

/// Microphones (CoreAudio input devices) for Pinpoint's built-in dictation.
enum AudioInputs {
    struct Device: Hashable, Identifiable { let id: AudioDeviceID; let uid: String; let name: String }

    private static func property<T>(_ obj: AudioObjectID, _ selector: AudioObjectPropertySelector,
                                    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, _ value: inout T) -> Bool {
        var addr = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<T>.size)
        return withUnsafeMutableBytes(of: &value) { AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, $0.baseAddress!) } == noErr
    }

    private static func string(_ obj: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String {
        var cf: Unmanaged<CFString>?
        guard property(obj, selector, &cf), let s = cf?.takeRetainedValue() else { return "" }
        return s as String
    }

    static func all() -> [Device] {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            var saddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeInput,
                                                   mElement: kAudioObjectPropertyElementMain)
            var ssize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &saddr, 0, nil, &ssize) == noErr, ssize > 0 else { return nil }
            return Device(id: id, uid: string(id, kAudioDevicePropertyDeviceUID), name: string(id, kAudioObjectPropertyName))
        }
    }

    static func systemDefault() -> Device? {
        var id = AudioDeviceID(0)
        guard property(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice, &id), id != 0 else { return nil }
        return all().first { $0.id == id }
    }

    static func device(uid: String) -> Device? { all().first { $0.uid == uid } }
}
