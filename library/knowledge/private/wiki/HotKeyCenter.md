---
type: entity
title: "HotKeyCenter"
entity: HotKeyCenter
kind: class
entity_type: service
target: Pinpoint
path: "Sources/Pinpoint/HotKeys.swift"
lines: "4-33"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[AppDelegate]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - app
related:
  - "[[AppDelegate]]"
---

# HotKeyCenter

## Purpose

System-wide shortcuts via Carbon's `RegisterEventHotKey`, which needs no Accessibility permission (`Sources/Pinpoint/HotKeys.swift:4`).

## API (internal)

```swift
final class HotKeyCenter {
    static let shared = HotKeyCenter()
    func register(keyCode: Int, modifiers: Int, id: UInt32, handler: @escaping () -> Void)
}
```

## Behaviour

- Installs one application event handler on first use that dispatches the pressed hotkey's id to its handler on the main queue (`HotKeys.swift:20-32`).
- Registration uses a fixed four-character signature (`OSType(0x504E5054)`) and logs when a hotkey is unavailable, for example already taken (`HotKeys.swift:15-17`).

## Called by

- [[AppDelegate]] `applicationDidFinishLaunching` registers ids 1 to 5 for the four capture modes and the library (`Sources/Pinpoint/AppDelegate.swift:26-30`).

## Related

[[AppDelegate]]

## Sources

- `Sources/Pinpoint/HotKeys.swift` (lines 4-33)
