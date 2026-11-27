---
type: entity
title: "Keychain"
entity: Keychain
kind: enum
entity_type: service
target: PinpointCore
path: "Sources/PinpointCore/Assistants.swift"
lines: "153-175"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[AppSettings]]"
  - "[[ChatGPTAccount]]"
tested_by: []
tags:
  - entity
  - pinpointcore
  - storage
related:
  - "[[AppSettings]]"
  - "[[ChatGPTAccount]]"
---

# Keychain

## Purpose

Stores secrets (provider API keys, ChatGPT credentials and app registration) as generic passwords in the macOS Keychain.

## API

```swift
public enum Keychain {
    public static let service = "app.pinpoint.apikeys"

    public static func get(_ account: String, service: String = Keychain.service) -> String
    @discardableResult
    public static func set(_ value: String, for account: String, service: String = Keychain.service) -> Bool
}
```

## Behaviour

- `get` returns the stored string, or `""` when missing (`Sources/PinpointCore/Assistants.swift:158-164`).
- `set` deletes any existing item first; an empty value just deletes and returns true (`Assistants.swift:167-174`).

> [!warning] Stored-data identifier
> Changing `Keychain.service` orphans users' saved keys unless a launch-time migration is added (project AGENTS.md; `library/knowledge/private/architecture/ADR-2-stored-data-identifiers.md`).

## Called by

- [[AppSettings]] `apiKey(_:)` and `setAPIKey(_:for:)`, using the [[ProviderKind]] raw value as the account (`Sources/Pinpoint/AppSettings.swift:65-66`).
- [[ChatGPTAccount]] for `chatgpt.credentials` and `chatgpt.registration` (`Sources/PinpointCore/ChatGPTPlan.swift:110-111`, `:119-137`).
- [[SettingsView]] indirectly, through [[AppSettings]] (`Sources/Pinpoint/SettingsView.swift:51-52`).

## Related

[[AppSettings]] · [[ChatGPTAccount]] · [[ProviderKind]] · [[SettingsView]]

## Sources

- `Sources/PinpointCore/Assistants.swift` (lines 153-175)
