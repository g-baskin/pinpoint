---
type: entity
title: "PinpointLog"
entity: PinpointLog
kind: enum
entity_type: utility
target: PinpointCore
path: "Sources/PinpointCore/Log.swift"
lines: "3-11"
language: swift
status: developing
partial_scan: false
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[AppDelegate]]"
  - "[[EditorModel]]"
  - "[[HotKeyCenter]]"
  - "[[ChatGPTAccount]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - core
related:
  - "[[AppDelegate]]"
---

# PinpointLog

## Purpose

Shared `os.Logger` instances, so every log line Pinpoint writes to the macOS unified log carries the subsystem `app.pinpoint.Pinpoint` and a category (`Sources/PinpointCore/Log.swift:3-11`).

## API

```swift
public enum PinpointLog {
    public static let subsystem = "app.pinpoint.Pinpoint"
    public static let app, capture, ai, storage, account: Logger
}
```

## Behaviour

- `subsystem` must equal `CFBundleIdentifier` in `Resources/Info.plist`; `LogTests` checks this, because the README's "Reporting a problem" `log show` command filters on it.
- Callers mark error descriptions and statuses `privacy: .public`, so they stay readable in logs users paste into bug reports (os.Logger otherwise redacts interpolated values as `<private>`).

## Called by

- [[AppDelegate]]: launch (`app`), capture failures (`capture`), AI naming (`ai`), meta writes (`storage`).
- [[EditorModel]]: failed save of recognised text (`storage`).
- [[HotKeyCenter]]: hotkey unavailable (`app`).
- [[ChatGPTAccount]]: failed Keychain save of a refreshed sign-in (`account`).

## Sources

- `Sources/PinpointCore/Log.swift`
- `Tests/PinpointCoreTests/LogTests.swift`
