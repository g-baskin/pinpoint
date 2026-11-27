# Pinpoint glossary

One name per concept. The code name is in brackets where it differs from the word used on screen.

- **Capture** [`CaptureMeta`, `CaptureMode`]: one screenshot taken by Pinpoint, plus everything saved about it (name, tags, OCR text, markup, crop). "Screenshot" means only the image itself.
- **Capture mode**: area, window, screen (the one under the mouse) or all screens.
- **Library** [`LibraryStore`, `LibraryModel`]: every saved capture, one folder per capture under `~/Pictures/Pinpoint/<id>/`.
- **Original / rendered / thumbnail**: the untouched image, the image with markup drawn on it, and the small preview, all stored in the capture's folder.
- **Markup item** [`Annotation`, `AnnotationKind`]: one thing drawn on a capture: arrow, line, rectangle, ellipse, text, callout, highlight, step, note, blur or redact.
- **Tool** [`Tool`]: an editor tool the user picks (each markup kind, plus select and crop).
- **Step**: a numbered badge. Steps are numbered automatically.
- **Note** [`.note`; "Voice note" in the editor]: a numbered comment pin whose explanation goes into handoffs.
- **Blur** and **redact**: blur smears an area, while the redact tool (X) covers it with a black box.
- **Auto-redact** [`SensitiveDetector`]: on-device detection of emails, keys, phone and card numbers, IPs, SSNs, faces and custom words, which are then blurred or black-boxed. It adds blur or redact markup items.
- **Analysis** [`Analyzer`, `Analysis`]: on-device OCR, sensitive-text boxes and face detection for a capture.
- **Guide** [`GuideBuilder`]: step-by-step document (`guide.md`, `guide.html`, images) made from several captures in order.
- **Handoff** [`Handoff`]: one capture's notes and markup written as text (copied, or exported as a folder with the image and `notes.md`) for a coding agent or teammate.
- **Provider** [`ProviderKind`]: the AI service in use (ChatGPT sign-in, Codex CLI, Anthropic, OpenAI, OpenRouter, Gemini, Ollama, custom).
- **Assistant** [`Assistants`, Assistant panel]: one-shot AI actions: summarize, name and tag, write a guide.
- **Agent** [`EditAgent`, `AgentToolbox`]: the AI loop that edits a capture by calling tools from a plain-English prompt.
