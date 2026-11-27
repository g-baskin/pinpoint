---
type: entity
title: "CodexClient"
entity: CodexClient
kind: struct
entity_type: service
target: PinpointCore
path: "Sources/PinpointCore/CodexClient.swift"
lines: "3-161"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[LLMClient]]"
  - "[[ChatMessage]]"
  - "[[ToolSpec]]"
  - "[[ChatResponse]]"
  - "[[JSONValue]]"
  - "[[LLMError]]"
used_by:
  - "[[ProviderSettings]]"
  - "[[AppSettings]]"
tested_by:
  - "Tests/PinpointCoreTests/ProviderTests.swift:95 OtherProviderTests.testCodexToolProtocol"
tags:
  - entity
  - pinpointcore
  - provider
related:
  - "[[LLMClient]]"
  - "[[ProviderSettings]]"
---

# CodexClient

## Purpose

The [[LLMClient]] for the "ChatGPT via Codex CLI" **provider**: uses the user's ChatGPT subscription through OpenAI's Codex CLI (`codex exec`). Codex has no tool-calling API here, so tools are offered through a JSON output schema `{"reply", "tool_calls": [{"name", "arguments_json"}]}` (`Sources/PinpointCore/CodexClient.swift:3-5`).

## API

```swift
public struct CodexClient: LLMClient {
    public var executable: URL
    public var model: String
    public var timeout: TimeInterval = 240

    public init(executable: URL, model: String)
    public static let suggestedModels = ["(Codex default)", "gpt-5.6-sol", "gpt-5.5", "gpt-5", "gpt-5-mini"]
    public static func locate(_ explicit: String = "") -> URL?
    public static func buildPrompt(system: String, messages: [ChatMessage], tools: [ToolSpec]) -> String
    public static func parse(_ text: String, expectTools: Bool) -> ChatResponse
    public func send(system: String, messages: [ChatMessage], tools: [ToolSpec], maxTokens: Int) async throws -> ChatResponse
}
```

## Behaviour

- `locate` checks an explicit path, then common install locations (bun, Homebrew, npm-global, local, volta, cargo, nvm) because Finder-launched apps get a minimal PATH (`CodexClient.swift:16-35`).
- `buildPrompt` flattens the conversation into one stateless prompt, listing tools with their JSON parameters (`CodexClient.swift:50-71`).
- `send` runs `codex exec --skip-git-repo-check --ephemeral -s read-only` in a temp directory, passes images with `-i`, adds `--output-schema` when tools are present, pipes the prompt on stdin, and reads `out.txt`. Login or auth errors in stderr get a "run `codex login`" message (`CodexClient.swift:89-122`).
- The process is killed after `timeout`; PATH is extended so Node or Bun scripts run (`CodexClient.swift:124-160`).
- `parse` turns the JSON reply into text and tool-use parts, falling back to plain text (`CodexClient.swift:74-87`).

## Called by

- [[ProviderSettings]] `makeClient` (`.codex`) and `listModels` (`suggestedModels`) (`Sources/PinpointCore/LLM.swift:281-284`, `:297`).
- [[AppSettings]] `isAIConfigured` calls `locate` (`Sources/Pinpoint/AppSettings.swift:75`).

## Related

[[LLMClient]] · [[ProviderSettings]] · [[ProviderKind]] · [[JSONValue]]

## Tested by

- `OtherProviderTests.testCodexToolProtocol` (`Tests/PinpointCoreTests/ProviderTests.swift:95`).

## Sources

- `Sources/PinpointCore/CodexClient.swift` (lines 3-161)
