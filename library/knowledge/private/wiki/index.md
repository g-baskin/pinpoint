---
type: meta
title: "Pinpoint code-entity wiki index"
status: developing
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
tags:
  - meta
  - index
---

# Pinpoint code-entity wiki

One page per code entity, grouped by Swift target. Terms follow `library/knowledge/private/glossary/glossary.md`.

## PinpointCore

- [[AgentState]]: the editable state (markup items, crop, name, tags) the **agent** works on.
- [[AgentToolbox]]: runs the agent's tool calls against an AgentState, with no network.
- [[Analysis]]: result of on-device **analysis**: OCR lines plus sensitive regions (and `OCRLine`).
- [[Analyzer]]: on-device analysis with Apple Vision; turns detections into **auto-redact** markup items.
- [[Annotation]]: one **markup item** on a capture, in image pixels.
- [[AnnotationKind]]: the kinds of markup item (arrow, line, rectangle, ellipse, text, callout, highlight, blur, redact, step, note).
- [[AnthropicClient]]: LLMClient for the Anthropic **provider** (Messages API).
- [[Assistants]]: the **assistant**: summarize, name and tag, write a **guide**.
- [[CaptureMeta]]: everything saved about one **capture** (`meta.json`).
- [[ChatGPTAccount]]: ChatGPT credentials, sign-in, refresh and sign-out.
- [[ChatGPTOAuth]]: constants and helpers for Sign in with ChatGPT (PKCE, app registration, loopback callback).
- [[ChatGPTPlanClient]]: LLMClient for the ChatGPT plan provider (Responses API).
- [[ChatMessage]]: provider-neutral chat message types (and `ChatRole`, `ChatPart`).
- [[ChatResponse]]: provider-neutral model reply.
- [[CodexClient]]: LLMClient that uses the Codex CLI (`codex exec`).
- [[EditAgent]]: the agent's tool-using loop over a capture.
- [[GuideBuilder]]: writes a guide (`guide.md`, `guide.html`, images) from captures in order (and `GuideStep`).
- [[Handoff]]: turns a capture's notes and markup into text for a coding agent or teammate.
- [[ImageFiles]]: image loading, encoding, writing and downscaling.
- [[JSONValue]]: Sendable JSON tree for tool schemas and payloads (and `extractJSONObject`).
- [[Keychain]]: stores API keys and ChatGPT credentials in the macOS Keychain.
- [[LLMClient]]: the provider-neutral client protocol.
- [[LLMError]]: the user-facing AI and sign-in error type.
- [[LibraryStore]]: the **library** on disk, one folder per capture.
- [[LoopbackListener]]: one-shot HTTP server on 127.0.0.1 for the OAuth redirect.
- [[Markdown]]: tiny Markdown to HTML converter for guides.
- [[ModelPicker]]: picks the best vision and tool-use model from a provider's list.
- [[OpenAICompatibleClient]]: LLMClient for OpenAI-compatible Chat Completions endpoints.
- [[ProviderKind]]: the provider catalogue with display names and defaults.
- [[ProviderSettings]]: per-provider settings and the LLMClient factory.
- [[RGBA]]: the colour value used by markup items.
- [[Renderer]]: draws markup items for the canvas and exported images.
- [[SensitiveDetector]]: auto-redact text detection of secrets and personal data (and `TextMatch`).
- [[SensitiveKind]]: the categories auto-redact detects.
- [[SensitiveRegion]]: one detected sensitive area with its box.
- [[ToolSpec]]: a tool offered to the model (and `ToolCall`).
- [[UIRegionDetector]]: finds toolbars, sidebars, panels and dialogs in a window screenshot.

## Pinpoint

- [[AppDelegate]]: app entry point and coordinator: menus, hotkeys, the capture flow and windows (and `CaptureMode`, `main.swift`).
- [[AppSettings]]: user preferences (UserDefaults) and API keys (Keychain).
- [[AssistantPanel]]: the editor's Assistant tab: assistant actions, AI log and agent prompt (and `LogRow`).
- [[CanvasView]]: the drawing surface for editing markup (and `CenteringClipView`, `CanvasScrollView`).
- [[CaptureService]]: screen and window capture with ScreenCaptureKit (and `WindowInfo`, `CaptureError`).
- [[EditorModel]]: state and actions of the editor for one capture (and `LogEntry`, `pinpointLibraryChanged`).
- [[ExternalDictation]]: detects a running dictation app; lists microphones (and `AudioInputs`).
- [[HotKeyCenter]]: system-wide shortcuts through Carbon.
- [[LibraryModel]]: observable library state: search, ordered selection, auto-name and make guide.
- [[LibraryView]]: the library grid of capture cards.
- [[MainView]]: SwiftUI content of the main window (and `TopBar`, `ToolStrip`, `EditorActions`, `ShareButton`, `EditorBody`, `EmptyEditor`).
- [[MainWindowController]]: hosts the single main window.
- [[NotePromptView]]: the Add more context? popover for typed or spoken notes (and `LevelMeter`).
- [[PropertiesPanel]]: the editor's Properties sidebar (and `ColorRow`, `NotesList`).
- [[QuickStyle]]: one-click style presets with rendered previews.
- [[SelectionOverlay]]: full-screen area and window picker (and `SelectionResult`, `SelectionView`).
- [[SettingsView]]: the Settings window (and `DisplaysList`).
- [[SpeechDictation]]: built-in on-device speech-to-text for voice notes.
- [[Tool]]: the editor **tool** the user picks.
- [[TrayView]]: the recent-captures tray with search and zoom (and `ZoomControls`).
- [[Workspace]]: state for the single window: editor, library and tray.
- [[ZoomController]]: zoom commands applied to the canvas scroll view.
