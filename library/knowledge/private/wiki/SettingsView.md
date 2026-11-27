---
type: entity
title: "SettingsView"
entity: SettingsView
kind: struct
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/SettingsView.swift"
lines: "5-232"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[AppSettings]]"
  - "[[ProviderKind]]"
  - "[[ProviderSettings]]"
  - "[[ChatGPTAccount]]"
  - "[[ModelPicker]]"
  - "[[LLMClient]]"
  - "[[ExternalDictation]]"
  - "[[LibraryStore]]"
used_by:
  - "[[AppDelegate]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - settings
  - view
related:
  - "[[AppSettings]]"
  - "[[ProviderSettings]]"
  - "[[ModelPicker]]"
---

# SettingsView (and DisplaysList)

## Purpose

The Settings window: AI **provider** setup (ChatGPT sign-in, model, base URL, API key, connection test), after-capture options including **auto-redact**, voice-note dictation and microphone choice, connected displays, shortcuts and the **library** folder. `DisplaysList` lists connected displays and refreshes when screens change.

## API (internal)

```swift
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
}

struct DisplaysList: View {
    var body: some View
}
```

Private: `chatGPTModelRow`, `chatGPTRow`, `func loadAutoPicks(refresh: Bool) async`, `func signIn()`, `func fetchModels()`, `func test()` (`SettingsView.swift:115-208`).

## Behaviour

- Provider section: a picker over `ProviderKind.allCases`; for ChatGPT, a sign-in row and a model picker; for other providers, a model field with a Fetch models menu, a base URL (or Codex path) field and, where needed, a Keychain API key field saved with `settings.setAPIKey` (`SettingsView.swift:21-65`).
- Changing the provider clears the fetched models, status and key draft (`SettingsView.swift:111`).
- The ChatGPT model picker offers `ModelPicker.auto` then ranked plan models; with Auto and a signed-in account it shows which models Auto picks for edits and for fast naming (`SettingsView.swift:115-142`).
- `signIn()` runs `ChatGPTAccount.shared.signIn`, opens the browser, then loads the plan's models; it can be cancelled (`SettingsView.swift:168-186`).
- `fetchModels()` calls `ProviderSettings.listModels(apiKey:)`; `test()` sends one short `ask` through `settings.makeClient()` (`SettingsView.swift:188-208`).
- After each capture: copy to clipboard, open in editor, auto-redact, custom redact terms and AI name and tag toggles (`SettingsView.swift:66-75`).
- Voice notes: ask for context, dictation source (`"auto"` or `"builtin"`), an indicator of a running [[ExternalDictation]] app, listen on prompt, and a built-in microphone picker from `AudioInputs.systemDefault()` and `AudioInputs.all()` (`SettingsView.swift:76-96`).
- Library section shows `LibraryStore.defaultRoot.path` (`SettingsView.swift:105-107`).
- `DisplaysList` shows each `NSScreen` with its pixel size and scale, and re-renders on `NSApplication.didChangeScreenParametersNotification` (`SettingsView.swift:212-231`).

## Called by

- [[AppDelegate]] hosts it in the Settings window (`Sources/Pinpoint/AppDelegate.swift:276`).

## Related

[[AppSettings]] · [[ProviderKind]] · [[ProviderSettings]] · [[ChatGPTAccount]] · [[ModelPicker]] · [[Keychain]] · [[ExternalDictation]] · [[LibraryStore]]

## Sources

- `Sources/Pinpoint/SettingsView.swift` (lines 5-232)
