---
type: entity
title: "Analyzer"
entity: Analyzer
kind: enum
entity_type: service
target: PinpointCore
path: "Sources/PinpointCore/Analyzer.swift"
lines: "18-91"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[Analysis]]"
  - "[[SensitiveDetector]]"
  - "[[SensitiveRegion]]"
  - "[[Annotation]]"
  - "[[AnnotationKind]]"
used_by:
  - "[[EditorModel]]"
  - "[[AppDelegate]]"
  - "[[AgentToolbox]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:83 AnalyzerTests"
tags:
  - entity
  - pinpointcore
  - analysis
related:
  - "[[Analysis]]"
  - "[[SensitiveDetector]]"
  - "[[AgentToolbox]]"
---

# Analyzer

## Purpose

On-device **analysis** with Apple Vision: text recognition, sensitive-text boxes and faces. No network (`Sources/PinpointCore/Analyzer.swift:18`). Also turns detections into **auto-redact** markup items.

## API

```swift
public enum Analyzer {
    public static func analyze(_ image: CGImage, faces: Bool = true, customTerms: [String] = []) throws -> Analysis
    public static func find(_ query: String, in lines: [OCRLine]) -> [OCRLine]
    public static func redactions(for regions: [SensitiveRegion], style: AnnotationKind = .blur,
                                  kinds: Set<SensitiveKind>? = nil, imageSize: CGSize) -> [Annotation]
    public static func suggestedName(from lines: [OCRLine], app: String?) -> String
}
```

## Behaviour

- `analyze` runs `VNRecognizeTextRequest` (accurate, no language correction) and optionally `VNDetectFaceRectanglesRequest`, sorts lines top-to-bottom then left-to-right, and converts Vision's normalised boxes to top-left pixel rects (`Analyzer.swift:20-38`). Each line goes through `SensitiveDetector.findMatches`, with a per-match bounding box when Vision provides one (`:43-46`). Face boxes are padded (`:48-52`).
- `find` is a case-insensitive substring match, falling back to word overlap (`Analyzer.swift:57-68`).
- `redactions` pads each region by `max(3, height * 0.15)`, clips to the image and returns blur or redact markup items (`Analyzer.swift:71-80`).
- `suggestedName` is the offline name: the first line with at least 4 letters, at most 80 chars and no sensitive match, else "<app> capture" or "Capture" (`Analyzer.swift:83-90`).

## Called by

- [[EditorModel]] `startAnalysis()` and `runAgent(_:)` call `analyze` with the user's redact terms; `autoRedact(style:)` calls `redactions` (`Sources/Pinpoint/EditorModel.swift:275`, `:291`, `:341`).
- [[AppDelegate]] `postProcess` calls `analyze(image, faces: false)` and `suggestedName` (`Sources/Pinpoint/AppDelegate.swift:207-209`).
- [[AgentToolbox]] uses `find` for `mark_text` and `redactions` for `redact_sensitive` (`Sources/PinpointCore/Agent.swift:145`, `:198`).

## Related

[[Analysis]] · [[SensitiveDetector]] · [[SensitiveRegion]] · [[AgentToolbox]] · [[EditorModel]] · [[AppDelegate]]

## Tested by

- `AnalyzerTests.testOCRFindsTextAndEmailBox` (`Tests/PinpointCoreTests/CoreTests.swift:84`).

## Sources

- `Sources/PinpointCore/Analyzer.swift` (lines 18-91)
