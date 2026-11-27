---
type: entity
title: "SensitiveDetector"
entity: SensitiveDetector
kind: enum
entity_type: service
target: PinpointCore
path: "Sources/PinpointCore/Sensitive.swift"
lines: "29-99"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[SensitiveKind]]"
used_by:
  - "[[Analyzer]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:6 SensitiveTests"
  - "Tests/PinpointCoreTests/CoreTests.swift:265 AccountIDTests"
tags:
  - entity
  - pinpointcore
  - auto-redact
related:
  - "[[Analyzer]]"
  - "[[SensitiveKind]]"
  - "[[AppSettings]]"
---

# SensitiveDetector (and TextMatch)

## Purpose

**Auto-redact** text detection: finds secrets and personal data in plain text. Pure and fast; runs on OCR output (`Sources/PinpointCore/Sensitive.swift:35`).

## API

```swift
public struct TextMatch: Equatable {
    public var kind: SensitiveKind
    public var range: Range<String.Index>
    public var value: String
}

public enum SensitiveDetector {
    public static func findMatches(in text: String, customTerms: [String] = []) -> [TextMatch]
}
```

Internal: `static let patterns: [(SensitiveKind, NSRegularExpression)]` (`Sensitive.swift:37-64`) and `static func luhnValid(_ s: String) -> Bool` (`:90-98`).

## Behaviour

- The user's custom words (2+ characters) match first, case- and diacritic-insensitive, as `.custom` (`Sensitive.swift:69-76`).
- Regex patterns then run in order: email; AWS, GitHub, Slack, Google, Stripe-style, JWT, `key=`/`token=` assignments, Meta, Google OAuth and Shopify tokens; Meta, Stripe and Google account IDs; card numbers; SSN; phone; IPv4; long numeric IDs (`Sensitive.swift:39-63`).
- Card-number matches must pass the Luhn check; any match overlapping an earlier, more specific one is skipped (`Sensitive.swift:81-83`).

## Called by

- [[Analyzer]] `analyze` per OCR line, with custom terms, and `suggestedName` to avoid naming a capture after sensitive text (`Sources/PinpointCore/Analyzer.swift:43`, `:86`). Custom terms come from [[AppSettings]] `redactTerms` via [[EditorModel]] (`Sources/Pinpoint/EditorModel.swift:273-275`).

## Related

[[Analyzer]] · [[SensitiveKind]] · [[SensitiveRegion]] · [[AppSettings]]

## Tested by

- `SensitiveTests` (`Tests/PinpointCoreTests/CoreTests.swift:6-22`) and `AccountIDTests` (`:265-293`).

## Sources

- `Sources/PinpointCore/Sensitive.swift` (lines 29-99)
