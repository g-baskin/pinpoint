---
type: entity
title: "SpeechDictation"
entity: SpeechDictation
kind: class
entity_type: service
target: Pinpoint
path: "Sources/Pinpoint/SpeechDictation.swift"
lines: "7-137"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[AppSettings]]"
  - "[[ExternalDictation]]"
used_by:
  - "[[NotePromptView]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - voice
  - speech
related:
  - "[[NotePromptView]]"
  - "[[ExternalDictation]]"
---

# SpeechDictation

## Purpose

Pinpoint's built-in, on-device speech-to-text for voice notes, built on Apple's Speech framework and `AVAudioEngine`. It publishes whether it is listening, the microphone level and the last error.

## API (internal)

```swift
@MainActor
final class SpeechDictation: ObservableObject {
    static let shared = SpeechDictation()

    @Published private(set) var isListening = false
    @Published private(set) var level: Float = 0
    @Published var lastError: String?

    var isAuthorized: Bool
    func authorize() async -> Bool
    func start(stopAfterSilence: TimeInterval? = nil, onUpdate: @escaping (String, Bool) -> Void) async
    func stop()
    nonisolated static func rms(_ buffer: AVAudioPCMBuffer) -> Float
}
```

## Behaviour

- The recognizer uses the current locale, falling back to `en-US` (`SpeechDictation.swift:19`).
- `authorize()` requests speech recognition, then microphone access, and sets `lastError` with the System Settings path when either is denied (`SpeechDictation.swift:31-39`).
- `start` stops any running session, authorizes, and requests partial results with punctuation, on-device only when the recognizer supports it (`SpeechDictation.swift:43-56`).
- It switches the input to `AppSettings.shared.micUID` when set, using `AudioInputs.device(uid:)` (`SpeechDictation.swift:58-64`), then taps the input, feeding buffers to the request and updating `level` (`:65-75`).
- Each result calls `onUpdate(text, isFinal)` and re-arms the silence timer; a final result or an error cleans up (`SpeechDictation.swift:77-89`). With `stopAfterSilence` set, it stops after that pause, and gives up after 7 s if nothing was heard (`:90-105`).
- `stop()` ends audio, removes the tap and finishes the task after 1.2 s so the final result can arrive (`SpeechDictation.swift:108-118`).
- `rms` returns the buffer's RMS times 12, capped at 1 (`SpeechDictation.swift:129-136`).

## Called by

- [[NotePromptView]] observes `SpeechDictation.shared` and calls `start` and `stop` (`Sources/Pinpoint/NotePrompt.swift:8`, `:117-137`).

## Related

[[NotePromptView]] · [[ExternalDictation]] · [[AppSettings]] · [[SettingsView]]

## Sources

- `Sources/Pinpoint/SpeechDictation.swift` (lines 7-137)
