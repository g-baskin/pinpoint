---
type: entity
title: "AppSettings"
entity: AppSettings
kind: class
entity_type: config-key
target: Pinpoint
path: "Sources/Pinpoint/AppSettings.swift"
lines: "4-91"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[ProviderKind]]"
  - "[[ProviderSettings]]"
  - "[[Keychain]]"
  - "[[ChatGPTAccount]]"
  - "[[ChatGPTPlanClient]]"
  - "[[CodexClient]]"
  - "[[ModelPicker]]"
  - "[[ExternalDictation]]"
  - "[[LLMClient]]"
used_by:
  - "[[AppDelegate]]"
  - "[[EditorModel]]"
  - "[[CanvasView]]"
  - "[[LibraryModel]]"
  - "[[SettingsView]]"
  - "[[AssistantPanel]]"
  - "[[NotePromptView]]"
  - "[[SpeechDictation]]"
  - "[[MainView]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - settings
related:
  - "[[SettingsView]]"
  - "[[ProviderSettings]]"
  - "[[Keychain]]"
---

# AppSettings

## Purpose

User preferences (UserDefaults) plus API keys (Keychain) (`Sources/Pinpoint/AppSettings.swift:4`). A main-actor singleton observed by SwiftUI views.

## API (internal)

```swift
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var provider: ProviderKind
    @Published var providers: [ProviderKind: ProviderSettings]
    @Published var autoNameWithAI: Bool
    @Published var copyAfterCapture: Bool
    @Published var openEditorAfterCapture: Bool
    @Published var autoRedactOnCapture: Bool
    @Published var askForContext: Bool
    @Published var listenOnPrompt: Bool
    @Published var dictationSource: String
    @Published var micUID: String
    @Published var customRedactTerms: String
    var redactTerms: [String]
    var activeExternalDictation: ExternalDictation?
    var current: ProviderSettings
    func apiKey(_ k: ProviderKind) -> String
    func setAPIKey(_ v: String, for k: ProviderKind) -> Bool
    var isAIConfigured: Bool
    func touch()
    func makeClient(fast: Bool = false) throws -> LLMClient
}
```

Each `@Published` property saves itself to UserDefaults in `didSet` under a key of the same name; `providers` is saved as a JSON array (`AppSettings.swift:10-25`, `:59-61`).

## Behaviour

- Defaults: provider `.chatgpt`; auto-name, copy after capture, open editor, ask for context and listen on prompt on; auto-redact on capture off; dictation source `"auto"` (`AppSettings.swift:35-57`).
- One-time migration sets the ChatGPT model to `ModelPicker.auto` (UserDefaults flag `chatgptAutoMigrated`) (`AppSettings.swift:42-46`).
- `redactTerms` splits `customRedactTerms` on commas and newlines, keeping terms of 2+ characters (`AppSettings.swift:26-28`).
- `activeExternalDictation` is nil when the source is `"builtin"`, else `ExternalDictation.running()` (`AppSettings.swift:31-33`).
- `setAPIKey(_:for:)` trims whitespace, stores the key in the [[Keychain]] and returns whether the Keychain write succeeded (`AppSettings.swift:66-70`).
- `isAIConfigured`: signed in for ChatGPT, Codex found, or key present when needed (`AppSettings.swift:72-78`).
- `makeClient(fast: true)` with ChatGPT on Auto returns a [[ChatGPTPlanClient]] on `auto-fast`; otherwise `current.makeClient(apiKey:)` (`AppSettings.swift:84-90`).

## Called by

- [[AppDelegate]] (capture options, AI naming), [[EditorModel]] (`redactTerms`, `makeClient`), [[CanvasView]] (`askForContext`, `listenOnPrompt`), [[LibraryModel]], [[SettingsView]], [[AssistantPanel]], [[NotePromptView]] (`activeExternalDictation`), [[SpeechDictation]] (`micUID`, `Sources/Pinpoint/SpeechDictation.swift:60`), [[MainView]].

## Related

[[SettingsView]] · [[ProviderSettings]] · [[ProviderKind]] · [[Keychain]] · [[ChatGPTAccount]] · [[ExternalDictation]]

## Sources

- `Sources/Pinpoint/AppSettings.swift` (lines 4-91)
