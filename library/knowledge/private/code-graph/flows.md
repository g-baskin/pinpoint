# Flows: Capture, Agent Edit and ChatGPT Sign-In

> Category: Code Graph | Version: 1.0 | Date: November 2026 | Status: Active

For contributors debugging or extending a user journey; traces three journeys call by call through the source with their guards, branches and failure paths.

**Related:**
- [`module-graph.md`](module-graph.md)
- [`type-graph.md`](type-graph.md)
- [`README.md`](README.md)
- [`../architecture/ADR-1-library-folder-per-capture.md`](../architecture/ADR-1-library-folder-per-capture.md)
- [`../architecture/ADR-3-chatgpt-app-registration-name.md`](../architecture/ADR-3-chatgpt-app-registration-name.md)

---

## Why this exists

The type and module graphs say what can call what. These sequence diagrams say what actually happens, in order, for the three journeys people most often ask about. Each was traced by reading the handlers, not by running the app; line numbers point at the code each step comes from. Solid arrows are calls, dashed arrows are returned values, `alt` blocks are mutually exclusive branches and `opt` blocks are optional steps. Nothing here runs in parallel unless it says `Task.detached`.

## 1. Capture: hotkey to saved library entry

This diagram follows **Control+Shift+1** (area or window mode). The full-screen and all-screens modes skip the overlay and go straight to `finishCapture`, which the first `alt` shows. The capture is on disk (`original.png`, `thumb.jpg`, `meta.json` in its own folder, per ADR-1) before the editor opens; OCR naming and AI tags arrive later from a detached task and rewrite `meta.json`.

```mermaid
sequenceDiagram
    actor user as User
    participant hotKeys as HotKeyCenter
    participant appDelegate as AppDelegate
    participant captureService as CaptureService
    participant overlay as SelectionOverlay
    participant store as LibraryStore
    participant imageFiles as ImageFiles
    participant workspace as Workspace
    participant editor as EditorModel
    participant bg as postProcess Task.detached

    user->>hotKeys: Control+Shift+1
    hotKeys->>appDelegate: handler on main queue, capture(.area)
    alt capturing is already true
        appDelegate-->>user: return, nothing happens
    end
    appDelegate->>captureService: screenUnderMouse(), visibleWindows()
    alt mode is screen or allScreens
        appDelegate->>captureService: captureScreen(mouseScreen) or captureAllScreens()
        captureService-->>appDelegate: CGImage, then finishCapture
    else area or window
        loop every NSScreen
            appDelegate->>captureService: captureScreen(screen)
            captureService-->>appDelegate: frozen CGImage
        end
        appDelegate->>overlay: init(screen, frozen, windows, preferWindow) and present
        user->>overlay: drag a region, click a window, or Esc
        overlay-->>appDelegate: completion(SelectionResult)
        appDelegate->>overlay: dismiss all overlays
        alt cancelled
            appDelegate-->>user: capturing = false, end
        else region
            appDelegate->>appDelegate: frozen.cropping(to: rect)
        else window in window mode
            appDelegate->>captureService: captureWindow(id, scale)
            captureService-->>appDelegate: CGImage (falls back to crop of frozen)
        end
    end
    opt a CaptureService call throws
        appDelegate-->>user: permission help alert or error alert, capturing = false
    end
    appDelegate->>store: create(image, name, sourceApp)
    store->>imageFiles: write original.png
    store->>imageFiles: writeThumb, thumb.jpg
    store->>store: writeMeta, meta.json
    store-->>appDelegate: CaptureMeta
    appDelegate->>appDelegate: post .pinpointLibraryChanged
    opt copyAfterCapture
        appDelegate->>imageFiles: encode(image), PNG to pasteboard
    end
    opt openEditorAfterCapture
        appDelegate->>workspace: open(meta, image)
        workspace->>workspace: saveCurrent() previous editor
        workspace->>editor: init(meta, base, library)
        editor->>editor: startAnalysis(), detached Analyzer.analyze
        opt autoRedactOnCapture
            appDelegate->>editor: autoRedact(.blur) once analysis exists
        end
    end
    appDelegate->>bg: postProcess(meta, image)
    bg->>store: meta(id)
    bg->>bg: Analyzer.analyze(faces false), suggestedName
    opt autoNameWithAI and AI configured
        bg->>bg: Assistants(client).nameAndTags
    end
    bg->>store: on MainActor, writeMeta (merged into open editor's meta if same id)
    bg->>bg: post .pinpointLibraryChanged
```

Source ledger:

| Step | Evidence |
|---|---|
| Hotkey registration and dispatch | `Sources/Pinpoint/AppDelegate.swift:25-30`, `Sources/Pinpoint/HotKeys.swift:11-17`, `:20-32` |
| Re-entry guard, screen and window lists | `AppDelegate.swift:118-124` |
| Screen and all-screens shortcut | `AppDelegate.swift:126-133` |
| Freeze every display, build overlays | `AppDelegate.swift:135-146` |
| Errors and permission help | `AppDelegate.swift:147-151`, `Sources/Pinpoint/CaptureService.swift:29-55` |
| Selection handling | `AppDelegate.swift:155-172`, `Sources/Pinpoint/SelectionOverlay.swift:4-9` |
| Save to library and notify | `AppDelegate.swift:174-179`, `Sources/PinpointCore/Library.swift:57-64`, `:78-86` |
| Copy, open editor, auto-redact | `AppDelegate.swift:180-186`, `:190-194`, `:230-234`, `Sources/Pinpoint/MainWindow.swift:25-30`, `Sources/Pinpoint/EditorModel.swift:136-147`, `:271-284` |
| Background naming and tagging | `AppDelegate.swift:197-223` |

Who hears `.pinpointLibraryChanged`: `LibraryModel` reloads its list (`Sources/Pinpoint/LibraryView.swift:19-21`) and `Workspace` closes the editor if its capture was deleted (`MainWindow.swift:20-22`, `:44-46`). A failure in `create` shows an alert and nothing is saved (`AppDelegate.swift:187`). Failures in the background task are swallowed with `try?`, so a capture keeps its placeholder name if OCR or AI naming fails.

## 2. Agent edit: prompt to undoable markup

The edit agent works on a copy of the editor state (`AgentState`) and the editor applies the result only after the run returns. If annotations or crop changed, it records one checkpoint first, so a single undo reverts the whole agent run. A thrown error or cancellation leaves the editor's markup untouched.

```mermaid
sequenceDiagram
    actor user as User
    participant panel as AssistantPanel
    participant editor as EditorModel
    participant settings as AppSettings
    participant agent as EditAgent
    participant toolbox as AgentToolbox
    participant client as LLMClient

    user->>panel: type instruction, press Return or send
    panel->>editor: runAgent(prompt)
    editor->>settings: makeClient()
    alt text empty, or makeClient throws
        editor-->>user: log error entry, return
    end
    settings-->>editor: LLMClient
    editor->>editor: runAI: guard not busy, log user entry, busy = true, agentTask = Task
    opt analysis not ready yet
        editor->>editor: detached Analyzer.analyze(base, customTerms)
    end
    editor->>agent: EditAgent(client).run(instruction, image, analysis, state, color, onEvent)
    agent->>agent: ImageFiles.forModel(image), build system prompt and OCR context
    agent->>toolbox: AgentToolbox(state, analysis, scale, color)
    loop at most maxSteps (12)
        agent->>agent: Task.checkCancellation()
        agent->>client: send(system, messages, AgentToolbox.tools, 2048)
        client-->>agent: ChatResponse
        alt no tool calls
            agent-->>editor: (box.state, reply text or "Done.")
        else tool calls
            loop each ToolCall
                agent->>toolbox: execute(name, input)
                toolbox-->>agent: (output, isError), state mutated in the copy
                agent-->>editor: onEvent, tool log entry on MainActor
            end
            agent->>agent: append toolResult message
        end
    end
    opt loop exhausted
        agent-->>editor: (box.state, "Stopped after 12 steps.")
    end
    opt annotations or crop differ from the editor
        editor->>editor: checkpoint() pushes (annotations, crop) to undoStack, clears redo, dirty = true
        editor->>editor: annotations = result.annotations, crop = result.crop
    end
    opt name or tags differ
        editor->>editor: meta.name, meta.tags = result values (not on the undo stack)
    end
    editor-->>user: log assistant reply, busy = false
    user->>editor: Command+Z via CanvasView.undo or MainWindowController.undo
    editor->>editor: undo() restores the pre-agent annotations and crop
```

Source ledger:

| Step | Evidence |
|---|---|
| Panel submit | `Sources/Pinpoint/EditorView.swift:77-81` |
| Guard, client creation | `Sources/Pinpoint/EditorModel.swift:306-309`, `:331-333`, `Sources/Pinpoint/AppSettings.swift:80-86`, `Sources/PinpointCore/LLM.swift:274-293` |
| runAI busy guard and error handling | `EditorModel.swift:362-372` |
| Analysis fallback | `EditorModel.swift:335-342` |
| Agent loop | `Sources/PinpointCore/Agent.swift:211-252` (`run`; `EditAgent` declared at `:205`) |
| Tool execution | `Agent.swift:83` (`AgentToolbox.execute`), tool specs at `Agent.swift:44` |
| Apply as one undoable step | `EditorModel.swift:348-356`, `:152-162` |
| Undo entry points | `Sources/Pinpoint/CanvasView.swift:272`, `Sources/Pinpoint/MainWindow.swift:135`, `:442` |

Cancellation: the stop button calls `cancelAI()` (`EditorModel.swift:360`), which cancels `agentTask`; the loop's `Task.checkCancellation()` throws `CancellationError`, which `runAI` swallows without logging an error. Name and tag changes from the agent are not part of the undo snapshot, which stores only `(annotations, crop)` (`EditorModel.swift:132-133`).

## 3. ChatGPT sign-in to first request

Sign-in is OAuth authorization code with PKCE against `auth.openai.com`, using dynamic app registration under the name "Pinpoint" (ADR-3) and a one-shot HTTP listener on `127.0.0.1` for the redirect. Tokens and the registration are stored in the Keychain. The first model request then goes to `https://api.openai.com/v1/responses` with the access token, refreshing it when it is within a minute of expiry.

```mermaid
sequenceDiagram
    actor user as User
    participant settingsView as SettingsView
    participant account as ChatGPTAccount
    participant oauth as ChatGPTOAuth
    participant listener as LoopbackListener
    participant browser as Browser
    participant authServer as auth.openai.com
    participant keychain as Keychain
    participant planClient as ChatGPTPlanClient
    participant api as api.openai.com

    user->>settingsView: Sign in with ChatGPT
    settingsView->>account: signIn(open:)
    account->>keychain: read saved registration
    account->>oauth: pkce(), random state and nonce
    account->>listener: start(expectedState, allowAnyPort: registration exists)
    alt port 1455 busy and no registration
        listener-->>account: throws LLMError, port busy
    end
    listener-->>account: listening on 127.0.0.1:port
    account->>oauth: authorizeRequestURL(clientId or dynamic_agent_client plus agent_name_hint)
    account->>settingsView: open(url)
    settingsView->>browser: NSWorkspace.open(url) on main queue
    browser->>authServer: authorize, user consents
    authServer-->>browser: redirect to /auth/callback?code, state, client_id
    browser->>listener: GET /auth/callback
    alt state matches
        listener-->>browser: 200 "You're signed in to Pinpoint."
        listener-->>account: query params
    else state mismatch or other path
        listener-->>browser: 400 or 404, keeps waiting
    end
    opt 180 s timeout or task cancelled
        listener-->>account: throws LLMError
    end
    alt params has error, or no code, or no issued client id
        account-->>settingsView: throws LLMError
    end
    account->>oauth: postForm(tokenURL, authorization_code, code_verifier, redirect_uri, resource)
    oauth->>authServer: POST /api/accounts/oauth/token
    authServer-->>account: access_token, refresh_token, id_token, scope, expires_in
    alt nonce claim differs, or scope lacks chatgpt.tokens.use.direct
        account-->>settingsView: throws LLMError
    end
    account->>keychain: save registration and credentials
    account->>listener: stop() (defer)
    account-->>settingsView: ChatGPTCredentials
    settingsView->>account: cachedModels(refresh: true) via loadAutoPicks
    account->>account: accessToken(), still fresh
    account->>api: GET /v1/models with Bearer token
    api-->>settingsView: model list, status shows count

    Note over user,api: First AI request, for example the agent run in flow 2
    planClient->>account: autoModel(fast, excluding, refresh) when model is auto
    account-->>planClient: ModelPicker.best(cached list)
    planClient->>account: accessToken()
    opt expires within 60 s
        account->>oauth: postForm(tokenURL, refresh_token)
        oauth->>authServer: POST token
        account->>keychain: save refreshed credentials
    end
    account-->>planClient: access token
    planClient->>api: POST /v1/responses, stream true, tools in the "pinpoint" namespace
    api-->>planClient: server-sent events
    planClient->>planClient: collect(events) into ChatResponse
    opt auto model refused with HTTP 404 or 400 model error
        planClient->>account: autoModel(excluding tried, refresh) and retry, at most 3 attempts
    end
```

Source ledger:

| Step | Evidence |
|---|---|
| Settings button and status | `Sources/Pinpoint/SettingsView.swift:168-186`, `:135-142` |
| PKCE, state, nonce, listener start | `Sources/PinpointCore/ChatGPTPlan.swift:150-157`, `:42-46`, `:259-265` |
| Authorize URL and browser open | `ChatGPTPlan.swift:158-160`, `:48-68` |
| Callback handling | `ChatGPTPlan.swift:299-320`, `:327-341` |
| Error, code and client id checks | `ChatGPTPlan.swift:161-170` |
| Token exchange, nonce and scope checks | `ChatGPTPlan.swift:171-182`, `:89-103` |
| Keychain storage | `ChatGPTPlan.swift:127-139`, `:187-188`, `Sources/PinpointCore/Assistants.swift:155-175` |
| Model list | `ChatGPTPlan.swift:232-242`, `:542-552` |
| Client creation for the first request | `Sources/Pinpoint/AppSettings.swift:80-86`, `Sources/PinpointCore/LLM.swift:275-279` |
| Auto model, token refresh, request | `ChatGPTPlan.swift:447-462`, `:193-223`, `:460-489`, `:554-558` |

A concurrent refresh is shared: `accessToken()` reuses one in-flight `refreshTask` under a lock (`ChatGPTPlan.swift:196-203`). A failed refresh surfaces as "Your ChatGPT sign-in expired" and does not clear the stored credentials (`ChatGPTPlan.swift:219-221`). The JWT is decoded without a signature check, as its doc comment states (`ChatGPTPlan.swift:70-78`).

## What these flows leave out

Drawing markup by hand on the canvas, voice notes, the library guide builder, export and handoff, the Codex CLI provider and the Anthropic or OpenAI-compatible request formats are not traced. None of these diagrams was checked by running the app; they are a reading of the source at the commit in [`README.md`](README.md).
