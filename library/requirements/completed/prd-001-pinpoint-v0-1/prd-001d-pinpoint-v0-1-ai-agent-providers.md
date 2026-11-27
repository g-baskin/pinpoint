# PRD-001d: AI agent, assistants and providers *(Retroactive)*

> **Status:** Shipped
> **Parent:** [PRD-001](./prd-001-pinpoint-v0-1-index.md)
> **Retroactive:** Yes. Written from source at commit `66349de`.

## What was built

AI features are optional. Everything in [prd-001a](./prd-001a-pinpoint-v0-1-capture.md) to [prd-001c](./prd-001c-pinpoint-v0-1-auto-redact-analysis.md) works without them.

### Provider-neutral client

`LLMClient` has one method, `send(system:messages:tools:maxTokens:)`, plus an `ask` helper for one-shot text (`Sources/PinpointCore/LLM.swift:51-60`). Messages are made of text, PNG images, tool calls and tool results (`LLM.swift:5-43`). HTTP errors are turned into `LLMError("HTTP <code>: <message>")` (`LLM.swift:62-73`).

### Providers

`ProviderKind` (`LLM.swift:222-264`). The default after install is ChatGPT (`Sources/Pinpoint/AppSettings.swift:36`).

| Provider | Client | Default base URL | Default model | Needs API key |
|---|---|---|---|---|
| ChatGPT (sign in with your plan) | `ChatGPTPlanClient` | `https://api.openai.com/v1` | `auto` | no |
| ChatGPT via Codex CLI | `CodexClient` | path to `codex`, empty = auto-detect | Codex default | no |
| Anthropic (Claude) | `AnthropicClient` | `https://api.anthropic.com` | `claude-sonnet-4-5` | yes |
| OpenAI API | `OpenAICompatibleClient` | `https://api.openai.com/v1` | `gpt-4.1` | yes |
| OpenRouter | `OpenAICompatibleClient` | `https://openrouter.ai/api/v1` | `openai/gpt-4.1-mini` | yes |
| Google Gemini | `OpenAICompatibleClient` | Gemini OpenAI-compatible endpoint | `gemini-2.5-flash` | yes |
| Ollama (local, offline) | `OpenAICompatibleClient` | `http://localhost:11434/v1` | `qwen2.5vl` | no |
| Custom (OpenAI-compatible) | `OpenAICompatibleClient` | `http://localhost:1234/v1` | none | no |

- `AnthropicClient` calls `v1/messages` with `anthropic-version: 2023-06-01` (`LLM.swift:77-135`).
- `OpenAICompatibleClient` calls `chat/completions` and sends tool results as `role: tool` messages. For OpenRouter it adds attribution headers (`LLM.swift:139-218`).
- **Fetch models** lists models from the provider (`LLM.swift:295-312`). Building a client checks the base URL, the model and the key, with plain error messages (`LLM.swift:274-293`).
- API keys are stored in the macOS Keychain under service `app.pinpoint.apikeys`, one account per provider (`Sources/PinpointCore/Assistants.swift:155-175`, `AppSettings.swift:65-66`). Other settings are in UserDefaults (`AppSettings.swift:4`).

### ChatGPT sign-in

`ChatGPTAccount` (`Sources/PinpointCore/ChatGPTPlan.swift:106-243`):

- Browser OAuth with PKCE, state and nonce against `auth.openai.com`. A one-shot loopback server on `127.0.0.1` catches the redirect, preferring port 1455, with a 180-second timeout (`ChatGPTPlan.swift:19-31`, `150-190`, `246-344`).
- The app registers as "Pinpoint" (`agentName`, `ChatGPTPlan.swift:25`; see [ADR-3](../../../knowledge/private/architecture/ADR-3-chatgpt-app-registration-name.md)). Sign-in fails unless the user allows the `chatgpt.tokens.use.direct` scope (`ChatGPTPlan.swift:27`, `177-179`).
- Credentials and the registration are stored in the Keychain; the access token is refreshed within a minute of expiry (`ChatGPTPlan.swift:117-147`, `192-223`).
- `ChatGPTPlanClient` streams the OpenAI Responses API, with tools in a `pinpoint` namespace (`ChatGPTPlan.swift:350-494`).
- Model `auto` picks the best model on the plan with `ModelPicker`, which drops audio, image, embedding and similar models and prefers newer GPT versions; `auto-fast` prefers "mini" models for background naming. On a 404 or a model-related 400 it tries up to 3 models. The plan's model list is cached for a day (`ChatGPTPlan.swift:447-462`, `492-559`, `Sources/Pinpoint/AppSettings.swift:79-86`).

### Codex CLI

`CodexClient` (`Sources/PinpointCore/CodexClient.swift`) runs `codex exec --ephemeral -s read-only` in a temporary folder that is deleted afterwards, with images passed as files (`CodexClient.swift:89-122`). Codex has no tool-calling API here, so tools are offered through a JSON output schema and the reply is parsed back into tool calls (`CodexClient.swift:3-5`, `37-87`). It searches common install paths because apps opened from Finder get a minimal `PATH` (`CodexClient.swift:15-35`).

### Assistants (one-shot)

`Assistants` (`Assistants.swift:6-53`):

- **Summarize**: 2 to 4 sentences plus bullets; saved to `summary` (`Sources/Pinpoint/EditorModel.swift:311-319`).
- **Name and tag**: JSON reply with a 3 to 7 word name and 3 to 6 tags; the prompt tells the model not to put secrets or personal data in them. Names are cut to 80 characters and tags to 8 (`Assistants.swift:18-35`).
- **Write guide**: see [prd-001e](./prd-001e-pinpoint-v0-1-library-guides.md).

### Edit agent

`EditAgent.run` (`Sources/PinpointCore/Agent.swift:205-252`):

1. Sends the capture downscaled to at most 1568 px on the long edge (`Sources/PinpointCore/ImageIO.swift:43-48`), up to 250 OCR lines with boxes, a count of sensitive items, the current markup and the request.
2. Loops up to 12 steps: each tool call runs against `AgentToolbox`, and the results go back to the model. It stops when the model replies without tool calls, or reports "Stopped after 12 steps."
3. Returns the edited state. The editor applies markup and crop changes as one undo step (`EditorModel.swift:331-358`). Each tool call is shown in the Assistant log. The user can stop a run (`EditorModel.swift:360`).

`AgentToolbox` (`Agent.swift:18-202`) has no network code and is unit-tested. Coordinates are converted between the image the model saw and the original pixels, and clamped to the image.

| Tool | What it does |
|---|---|
| `add_annotation` | adds one markup item of any kind; steps number themselves; text, callout and note need text |
| `mark_text` | finds OCR text and marks every match (or the first) with an arrow and optional label, rectangle, ellipse, highlight, blur, redact or step; if nothing matches it returns visible text so the model can retry |
| `redact_sensitive` | covers detected sensitive items with blur or redact, optionally only some kinds |
| `list_annotations` | lists markup with short ids and positions |
| `remove_annotations` | removes by id, or all |
| `crop` | sets or resets the crop |
| `set_name_and_tags` | renames the capture and sets tags |

## Acceptance criteria

| ID | Given | When | Then |
|---|---|---|---|
| AC-1 | an Anthropic provider with no key | the user runs the agent | the error says to add the API key in Settings |
| AC-2 | a capture with a "Save" button | the user asks "point an arrow at Save" | an arrow points at the Save text, and one ⌘Z removes it |
| AC-3 | ChatGPT is chosen and signed in, model `auto` | the plan rejects the chosen model with HTTP 404 | the client refreshes the list and tries another model, up to 3 attempts |
| AC-4 | the Codex CLI is not installed | the user runs the agent | the error says how to install it and sign in |
| AC-5 | the model keeps calling tools | 12 steps have run | the run stops and keeps the edits made so far |

## Tests

`AgentToolboxTests`, `AgentLoopTests` and `ProviderWireTests` in `Tests/PinpointCoreTests/CoreTests.swift` (lines 116, 186, 203); `ChatGPTPlanTests`, `OtherProviderTests` and `ModelPickerTests` in `Tests/PinpointCoreTests/ProviderTests.swift` (lines 5, 80, 107).

## Related

- [Glossary: provider, assistant, agent](../../../knowledge/private/glossary/glossary.md)
- [ADR-2](../../../knowledge/private/architecture/ADR-2-stored-data-identifiers.md): `Keychain.service` must not change without a migration
- [ADR-3](../../../knowledge/private/architecture/ADR-3-chatgpt-app-registration-name.md)
