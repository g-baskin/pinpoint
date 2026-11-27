---
type: entity
title: "ChatGPTOAuth"
entity: ChatGPTOAuth
kind: enum
entity_type: module
target: PinpointCore
path: "Sources/PinpointCore/ChatGPTPlan.swift"
lines: "19-104"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[JSONValue]]"
  - "[[LLMError]]"
used_by:
  - "[[ChatGPTAccount]]"
  - "[[LoopbackListener]]"
  - "[[ChatGPTPlanClient]]"
tested_by:
  - "Tests/PinpointCoreTests/ProviderTests.swift:5 ChatGPTPlanTests"
tags:
  - entity
  - pinpointcore
  - provider
  - auth
related:
  - "[[ChatGPTAccount]]"
  - "[[LoopbackListener]]"
  - "[[ChatGPTPlanClient]]"
---

# ChatGPTOAuth

## Purpose

Constants and pure helpers for "Sign in with ChatGPT": PKCE plus dynamic app registration ("Pinpoint") at auth.openai.com, a loopback callback on 127.0.0.1:1455, and requests to the OpenAI Responses API (`Sources/PinpointCore/ChatGPTPlan.swift:5-7`).

## API

```swift
public enum ChatGPTOAuth {
    public static let issuer = "https://auth.openai.com"
    public static let authorizeURL = "\(issuer)/api/accounts/authorize"
    public static let tokenURL = "\(issuer)/api/accounts/oauth/token"
    public static let revokeURL = "\(issuer)/api/accounts/oauth/revoke"
    public static let registrationClientId = "dynamic_agent_client"
    public static let agentName = "Pinpoint"
    public static let resource = "https://api.openai.com/v1"
    public static let planScope = "chatgpt.tokens.use.direct"
    public static let scopes = "openid profile email offline_access resource.invoke \(planScope)"
    public static let apiBase = "https://api.openai.com/v1"
    public static let callbackPath = "/auth/callback"
    public static let preferredPort: UInt16 = 1455

    public static func base64url(_ data: Data) -> String
    public static func randomBytes(_ n: Int) -> Data
    public static func pkce() -> (verifier: String, challenge: String)
    public static func authorizeRequestURL(clientId: String?, hostId: String, email: String?, redirectURI: String,
                                           state: String, nonce: String, challenge: String) -> URL
    public static func jwtClaims(_ token: String) -> JSONValue?
}
```

Internal: `static func formBody(_ fields: [String: String]) -> Data` and `static func postForm(_ url: String, _ fields: [String: String]) async throws -> JSONValue` (`ChatGPTPlan.swift:80-103`).

## Behaviour

- `pkce` makes a 32-byte base64url verifier and its SHA-256 S256 challenge (`ChatGPTPlan.swift:42-46`).
- `authorizeRequestURL` uses `registrationClientId` plus `agent_name_hint` on first sign-in, or the issued client id afterwards (`ChatGPTPlan.swift:48-68`).
- `jwtClaims` decodes the JWT payload without a signature check; the comment explains the token came straight from auth.openai.com over TLS (`ChatGPTPlan.swift:70-78`).
- `postForm` posts form-encoded fields and throws [[LLMError]] with the server's `error_description` on non-2xx (`ChatGPTPlan.swift:89-103`).

> [!note] Registration name
> `agentName = "Pinpoint"` is the name shown on the user's ChatGPT consent screen; see `library/knowledge/private/architecture/ADR-3-chatgpt-app-registration-name.md`.

## Called by

- [[ChatGPTAccount]] `signIn`, `refresh`, `signOut`, `models` (`ChatGPTPlan.swift:152-243`).
- [[LoopbackListener]] uses `preferredPort` and `callbackPath` (`ChatGPTPlan.swift:261`, `:304`).
- [[ChatGPTPlanClient]] uses `apiBase` (`ChatGPTPlan.swift:462`).

## Related

[[ChatGPTAccount]] · [[LoopbackListener]] · [[ChatGPTPlanClient]] · [[JSONValue]] · [[LLMError]]

## Tested by

- `ChatGPTPlanTests`: PKCE, authorize URL for first and returning sign-in, JWT claims (`Tests/PinpointCoreTests/ProviderTests.swift:6-34`).

## Sources

- `Sources/PinpointCore/ChatGPTPlan.swift` (lines 19-104)
