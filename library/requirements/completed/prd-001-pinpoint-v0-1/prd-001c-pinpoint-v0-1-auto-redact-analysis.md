# PRD-001c: On-device analysis and auto-redact *(Retroactive)*

> **Status:** Shipped
> **Parent:** [PRD-001](./prd-001-pinpoint-v0-1-index.md)
> **Retroactive:** Yes. Written from source at commit `66349de`.

## What was built

All analysis runs on the Mac with Apple Vision and regular expressions. It makes no network calls and needs no AI provider (`Sources/PinpointCore/Analyzer.swift:18`).

### Analysis

`Analyzer.analyze` (`Analyzer.swift:20-54`) returns an `Analysis`: OCR lines plus sensitive regions (`Analyzer.swift:11-16`).

- Text: `VNRecognizeTextRequest` at `.accurate`, language correction off. Lines are sorted top to bottom, then left to right, and stored in image pixels with a top-left origin (`Analyzer.swift:26-42`).
- Each OCR line goes through `SensitiveDetector`. A match is boxed using the exact character range when Vision can give it, else the whole line (`Analyzer.swift:43-46`).
- Faces: `VNDetectFaceRectanglesRequest`, each box grown by 15% of its width on each side and 20% of its height (`Analyzer.swift:48-52`). The background pass after capture skips faces (`Sources/Pinpoint/AppDelegate.swift:203`).

The editor starts analysis when a capture opens, including the user's custom words, and fills `ocrText` if it was empty (`Sources/Pinpoint/EditorModel.swift:271-284`).

### Sensitive kinds and patterns

`SensitiveKind` (`Sources/PinpointCore/Sensitive.swift:4-20`): email, API key / secret, account / ad ID, phone, card number, IP address, SSN, custom word, face.

`SensitiveDetector.findMatches` (`Sensitive.swift:66-88`):

1. The user's custom words first: each term of at least 2 characters, matched case- and diacritic-insensitively anywhere in the text (`Sensitive.swift:69-76`).
2. Then the pattern list in order (`Sensitive.swift:37-63`). A later match that overlaps an earlier one is skipped, so more specific patterns win.
   - API keys and secrets: AWS access key ids, GitHub tokens, Slack tokens, Google API keys, `sk`/`pk`/`rk` style keys, JWTs, `api_key=` / `secret=` / `token=` / `password=` assignments, Meta access tokens, Google OAuth access tokens, Shopify tokens.
   - Account and ad IDs: Meta ad accounts (`act_`), Stripe object IDs, GA4, Universal Analytics, Google Tag Manager, Google Ads conversion and customer IDs, and any 15 to 19 digit number.
   - Card numbers: 13 to 19 digits, kept only if they pass the Luhn check (`Sensitive.swift:81`, `90-98`).
   - SSN (`ddd-dd-dddd`), phone numbers, IPv4 addresses, emails.

### Auto-redact

`Analyzer.redactions` (`Analyzer.swift:70-80`) turns regions into blur or redact markup items, padded by the larger of 3 px and 15% of the region height and clipped to the image. Because they are ordinary markup items, the user can move or delete them.

Entry points:

- Assistant panel buttons **Blur** and **Black boxes** (`Sources/Pinpoint/EditorView.swift:29-30`), which call `EditorModel.autoRedact` as one undo step and report counts per kind (`EditorModel.swift:286-293`).
- **Auto-blur sensitive info (on-device)** after every capture, off by default (`Sources/Pinpoint/SettingsView.swift:69`, `Sources/Pinpoint/AppSettings.swift:51`).
- The agent's `redact_sensitive` tool (see [prd-001d](./prd-001d-pinpoint-v0-1-ai-agent-providers.md)).

**Always redact these words** is a comma- or newline-separated setting (`SettingsView.swift:70`, `AppSettings.swift:24-28`).

### Copy text and offline naming

- **Copy text** puts all OCR text on the clipboard (`EditorModel.swift:295-303`).
- `Analyzer.suggestedName` picks the first OCR line with at least 4 letters, at most 80 characters and no sensitive match, else `<app> capture` (`Analyzer.swift:82-90`).
- `Analyzer.find` locates text for the agent: substring match first, then any shared word (`Analyzer.swift:56-68`).

## Acceptance criteria

| ID | Given | When | Then |
|---|---|---|---|
| AC-1 | a capture shows an email address and no network | the user clicks **Blur** | a blur item covers the email |
| AC-2 | a 16-digit number that fails the Luhn check | analysis runs | it is not reported as a card number (it may still match as a long numeric ID) |
| AC-3 | "Acme Corp" is in **Always redact these words** | a capture shows "acme corp" | it is covered |
| AC-4 | a capture shows a face | the user clicks **Black boxes** | a black box covers the face with some margin |
| AC-5 | nothing sensitive is found | the user clicks **Blur** | no markup is added and the panel says nothing was found |

## Tests

`SensitiveTests`, `AnalyzerTests` and `AccountIDTests` in `Tests/PinpointCoreTests/CoreTests.swift` (lines 6, 83, 265).

## Related

- [Glossary: auto-redact, analysis](../../../knowledge/private/glossary/glossary.md)
