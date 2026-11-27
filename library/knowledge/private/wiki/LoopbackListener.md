---
type: entity
title: "LoopbackListener"
entity: LoopbackListener
kind: class
entity_type: class
target: PinpointCore
visibility: internal
path: "Sources/PinpointCore/ChatGPTPlan.swift"
lines: "246-344"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[ChatGPTOAuth]]"
  - "[[LLMError]]"
used_by:
  - "[[ChatGPTAccount]]"
tested_by: []
tags:
  - entity
  - pinpointcore
  - auth
related:
  - "[[ChatGPTAccount]]"
  - "[[ChatGPTOAuth]]"
---

# LoopbackListener

## Purpose

A minimal one-shot HTTP server on 127.0.0.1 that captures the OAuth redirect (`Sources/PinpointCore/ChatGPTPlan.swift:246`). Internal to PinpointCore.

## API (internal)

```swift
final class LoopbackListener: @unchecked Sendable {
    let listener: NWListener
    let port: UInt16
    static func start(expectedState: String, allowAnyPort: Bool) async throws -> LoopbackListener
    func waitForCallback(timeout: TimeInterval) async throws -> [String: String]
    func stop()
}
```

## Behaviour

- `start` binds port 1455; when `allowAnyPort` is true (a returning user with a registration) it falls back to any port. If binding fails it throws an [[LLMError]] saying port 1455 is busy (`ChatGPTPlan.swift:259-265`).
- Each connection reads the request line; only `ChatGPTOAuth.callbackPath` with a matching `state` resolves the wait with the query parameters, otherwise 400 or 404 (`ChatGPTPlan.swift:295-316`).
- `waitForCallback` fails with a timeout error after `timeout` seconds and with a cancellation error if the task is cancelled (`ChatGPTPlan.swift:327-341`).

## Called by

- [[ChatGPTAccount]] `signIn` (`Sources/PinpointCore/ChatGPTPlan.swift:155-161`).

## Related

[[ChatGPTAccount]] · [[ChatGPTOAuth]]

## Sources

- `Sources/PinpointCore/ChatGPTPlan.swift` (lines 246-344)
