---
type: entity
title: "ExternalDictation"
entity: ExternalDictation
kind: struct
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/DictationSources.swift"
lines: "5-92"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[AppSettings]]"
  - "[[NotePromptView]]"
  - "[[SettingsView]]"
  - "[[SpeechDictation]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - voice
related:
  - "[[SpeechDictation]]"
  - "[[NotePromptView]]"
  - "[[AppSettings]]"
---

# ExternalDictation (and AudioInputs)

## Purpose

`ExternalDictation` detects a running third-party dictation app that types into the focused text field, so Pinpoint only keeps the note box focused and avoids clashing with the app's push-to-talk key. `AudioInputs` lists CoreAudio input devices (microphones) for the built-in dictation.

## API (internal)

```swift
struct ExternalDictation: Equatable {
    let name: String
    let bundleID: String
    let hint: String
    let usesOption: Bool

    static let known: [(String, String)]
    static func running() -> ExternalDictation?
    static let keyNames: [Int: String]
    static func wisprPushToTalk() -> (label: String, usesOption: Bool)?
}

enum AudioInputs {
    struct Device: Hashable, Identifiable { let id: AudioDeviceID; let uid: String; let name: String }

    static func all() -> [Device]
    static func systemDefault() -> Device?
    static func device(uid: String) -> Device?
}
```

## Behaviour

- `known` lists bundle IDs and names for Wispr Flow, Superwhisper, Aqua Voice, VoiceInk and MacWhisper (`DictationSources.swift:14-20`).
- `running()` returns the first known app among `NSWorkspace.shared.runningApplications`. For Wispr Flow it reads the push-to-talk key for the hint and `usesOption`; other apps get a generic hint and `usesOption: false` (`DictationSources.swift:23-32`).
- `wisprPushToTalk()` reads `~/Library/Application Support/Wispr Flow/config.json` read-only, finds the `"ptt"` shortcut, names its key codes through `keyNames`, and sets `usesOption` when the combo includes left or right Option (codes 58, 61). If the file cannot be read it returns a generic label with `usesOption` false (`DictationSources.swift:39-49`).
- `AudioInputs.all()` lists devices that have input streams, with their UID and name (`DictationSources.swift:69-83`). `systemDefault()` finds the default input device (`:85-89`); `device(uid:)` looks one up by UID (`:91`).

## Called by

- [[AppSettings]] `activeExternalDictation` returns nil for the `"builtin"` source, else `ExternalDictation.running()` (`Sources/Pinpoint/AppSettings.swift:31-33`).
- [[NotePromptView]] reads it on appear (`Sources/Pinpoint/NotePrompt.swift:69`).
- [[SettingsView]] shows the running app and the microphone picker (`Sources/Pinpoint/SettingsView.swift:86`, `:95-96`).
- [[SpeechDictation]] uses `AudioInputs.device(uid:)` (`Sources/Pinpoint/SpeechDictation.swift:61`).

## Related

[[SpeechDictation]] · [[NotePromptView]] · [[AppSettings]] · [[SettingsView]]

## Sources

- `Sources/Pinpoint/DictationSources.swift` (lines 5-92)
