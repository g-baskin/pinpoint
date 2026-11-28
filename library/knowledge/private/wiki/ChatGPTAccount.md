---
type: entity
title: "ChatGPTAccount"
entity: ChatGPTAccount
kind: class
entity_type: service
target: PinpointCore
path: "Sources/PinpointCore/ChatGPTPlan.swift"
lines: "9-17, 106-250, 543-565"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[ChatGPTOAuth]]"
  - "[[LoopbackListener]]"
  - "[[Keychain]]"
  - "[[ModelPicker]]"
  - "[[JSONValue]]"
  - "[[LLMError]]"
used_by:
  - "[[ChatGPTPlanClient]]"
  - "[[ProviderSettings]]"
  - "[[AppSettings]]"
  - "[[SettingsView]]"
tested_by: []
tags:
  - entity
  - pinpointcore
  - provider
  - auth
related:
  - "[[ChatGPTOAuth]]"
  - "[[ChatGPTPlanClient]]"
  - "[[ModelPicker]]"
---

# ChatGPTAccount (and ChatGPTCredentials)

## Purpose

Stores the ChatGPT credentials and app registration and performs sign-in, refresh and sign-out (`Sources/PinpointCore/ChatGPTPlan.swift:106`). A process-wide singleton, `shared`.

## API

```swift
public struct ChatGPTCredentials: Codable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Date
    public var clientId: String
    public var subject: String
    public var email: String?
    public var idToken: String?
}

public final class ChatGPTAccount: @unchecked Sendable {
    public static let shared = ChatGPTAccount()
    public var credentials: ChatGPTCredentials?
    public var isSignedIn: Bool
    public var email: String?

    public func signIn(open: @escaping @Sendable (URL) -> Void) async throws -> ChatGPTCredentials
    public func accessToken() async throws -> String
    public func signOut() async
    public func models() async throws -> [String]
}

extension ChatGPTAccount {
    public func cachedModels(refresh: Bool = false) async throws -> [String]
    public func autoModel(fast: Bool = false, excluding: Set<String> = [], refresh: Bool = false) async throws -> String
}
```

Grouped internal type: `struct Registration: Codable { var clientId: String; var subject: String; var email: String? }` (`ChatGPTPlan.swift:115`).

## Behaviour

- Credentials and registration are JSON strings in the [[Keychain]] under `chatgpt.credentials` and `chatgpt.registration`, cached behind an `NSLock` (`ChatGPTPlan.swift:109-142`). `save(_:)` (`@discardableResult`) returns whether the Keychain write succeeded, and `nil` clears the item (`:127-133`); `registration` is read-only and `saveRegistration(_:)` returns the write's result (`:135-142`). A stable `urn:uuid:` host id lives in UserDefaults key `chatgptHostId` (`:144-150`).
- `signIn` starts a [[LoopbackListener]], opens the authorize URL via the `open` callback, waits up to 180 s, exchanges the code, checks the nonce, and requires the `planScope` scope before saving (`ChatGPTPlan.swift:153-195`). If either the registration or credentials write fails, it clears the credentials and throws an [[LLMError]] ("Signed in, but Pinpoint couldn't save the sign-in to your Keychain…") (`:190-193`).
- `accessToken` refreshes when within 60 s of expiry; concurrent callers share one refresh task (`ChatGPTPlan.swift:198-209`). If saving the refreshed token fails, `refresh` logs it with `PinpointLog.account` and still returns the token for this session (`:222-223`).
- `signOut` revokes the refresh token (errors ignored) and clears storage (`ChatGPTPlan.swift:230-235`).
- `models` lists the plan's models; `cachedModels` caches the list for a day in UserDefaults; `autoModel` picks via [[ModelPicker]] (`ChatGPTPlan.swift:238-248`, `:548-564`).

## Called by

- [[ChatGPTPlanClient]] `accessToken()` and `autoModel(...)` (`ChatGPTPlan.swift:460`, `:467`).
- [[ProviderSettings]] `makeClient` and `listModels` (`Sources/PinpointCore/LLM.swift:276`, `:296`).
- [[AppSettings]] `isAIConfigured` and `makeClient(fast:)` (`Sources/Pinpoint/AppSettings.swift:74`, `:86`).
- [[SettingsView]] sign-in, sign-out and model rows (`Sources/Pinpoint/SettingsView.swift:132-176`).

## Related

[[ChatGPTOAuth]] · [[LoopbackListener]] · [[ChatGPTPlanClient]] · [[ModelPicker]] · [[Keychain]] · [[SettingsView]]

## Sources

- `Sources/PinpointCore/ChatGPTPlan.swift` (lines 9-17, 106-250, 543-565)
