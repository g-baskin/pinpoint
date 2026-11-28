# Flows: Capture, Scrolling Capture, Agent Edit and ChatGPT Sign-In

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

The type and module graphs say what can call what. These sequence diagrams say what actually happens, in order, for the four journeys people most often ask about. Each was traced by reading the handlers, not by running the app; line numbers point at the code each step comes from. Solid arrows are calls, dashed arrows are returned values, `alt` blocks are mutually exclusive branches and `opt` blocks are optional steps. Nothing here runs in parallel unless it says `Task.detached`.

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
| Hotkey registration and dispatch | `Sources/Pinpoint/AppDelegate.swift:27-32`, `Sources/Pinpoint/HotKeys.swift:11-17`, `:20-32` |
| Re-entry guard, screen and window lists | `AppDelegate.swift:123-131` |
| Screen and all-screens shortcut | `AppDelegate.swift:134-141` |
| Freeze every display, build overlays | `AppDelegate.swift:142-157` |
| Errors and permission help | `AppDelegate.swift:158-162`, `Sources/Pinpoint/CaptureService.swift:29-55` |
| Selection handling | `AppDelegate.swift:166-188`, `Sources/Pinpoint/SelectionOverlay.swift:4-10` |
| Save to library and notify | `AppDelegate.swift:205-210`, `Sources/PinpointCore/Library.swift:57-64`, `:78-86` |
| Copy, open editor, auto-redact | `AppDelegate.swift:211-215`, `:221-225`, `:269-273`, `Sources/Pinpoint/MainWindow.swift:25-30`, `Sources/Pinpoint/EditorModel.swift:136-147`, `:271-285` |
| Background naming and tagging | `AppDelegate.swift:228-262` |

Who hears `.pinpointLibraryChanged`: `LibraryModel` reloads its list (`Sources/Pinpoint/LibraryView.swift:19-21`) and `Workspace` closes the editor if its capture was deleted (`MainWindow.swift:20-22`, `:47-49`). A failure in `create` shows an alert and nothing is saved (`AppDelegate.swift:218`). In the background task, an OCR failure is still absorbed with `try?` (empty analysis); a failed `makeClient`, AI naming call or final `writeMeta` is logged with `NSLog` (`AppDelegate.swift:233`, `:245`, `:258-259`). The capture keeps its offline or placeholder name when AI naming fails. `openImage` collects unreadable or uncreatable files and shows one error alert listing them (`AppDelegate.swift:292-309`).

## 2. Scrolling capture: pick an area, scroll, stitch

This diagram follows **Control+Shift+5** (or the Scrolling Capture menu item, or S in the overlay). It reuses the frozen-screen picker from flow 1; only the pick's result differs. After that the screen is live: Pinpoint grabs the picked rectangle about every 80 ms while the user scrolls by hand, and `ScrollStitcher` joins the frames off the main thread. No Accessibility permission is involved, because Pinpoint never scrolls for the user.

```mermaid
sequenceDiagram
    actor user as User
    participant appDelegate as AppDelegate
    participant overlay as SelectionOverlay
    participant session as ScrollCaptureSession
    participant scKit as SCScreenshotManager
    participant stitcher as ScrollStitcher
    participant frontApp as Previous front app

    user->>appDelegate: Control+Shift+5, capture(.scrolling)
    alt scrollSession already exists
        appDelegate->>session: finish() (shortcut acts as Done)
    end
    appDelegate->>overlay: init(..., scrolling: true) on every frozen screen
    user->>overlay: drag an area, click a panel or window, or full screen
    overlay-->>appDelegate: completion(.scrolling(rect px))
    appDelegate->>appDelegate: startScrolling(rect in points, screen, frontRunning)
    appDelegate->>session: init(screen, rect, scale, previousApp), start()
    session->>scKit: captureImage(display filter without Pinpoint, sourceRect)
    alt capture throws
        session-->>appDelegate: error, permission help or error alert, capturing = false
    end
    scKit-->>session: first frame
    session->>stitcher: add(first), .started
    session->>session: show outline window and Done/Cancel panel
    session->>frontApp: activate()
    loop while running, about every 80 ms
        user->>frontApp: scroll the page
        session->>scKit: captureImage(same filter and sourceRect)
        scKit-->>session: frame
        session->>stitcher: Task.detached, add(frame)
        stitcher-->>session: Step (added, unchanged, lostTrack, full)
        session->>session: update height and hint in panel
    end
    alt Done, or Control+Shift+5 again
        user->>session: finish()
        session->>session: await loop end
        session->>stitcher: makeImage()
        stitcher-->>session: stitched CGImage
        session-->>appDelegate: completion(image)
        appDelegate->>appDelegate: finishCapture(image, app), as in flow 1
    else Cancel
        user->>session: cancel()
        session-->>appDelegate: completion(nil), capturing = false
    end
```

Source ledger:

| Step | Evidence |
|---|---|
| Shortcut, menu items, Done-by-shortcut guard | `Sources/Pinpoint/AppDelegate.swift:31`, `:67`, `:95`, `:115`, `:123-126` |
| Overlay in scrolling mode, S key, toolbar button | `Sources/Pinpoint/SelectionOverlay.swift:8`, `:18`, `:70-76`, `:93-94`, `:311-325`, `:378` |
| Pixel rect to points, session start and errors | `AppDelegate.swift:184-203` |
| First frame, filter without Pinpoint, `sourceRect` | `Sources/Pinpoint/ScrollCaptureSession.swift:34-49` |
| Outline, panel, re-activate previous app | `ScrollCaptureSession.swift:50-53`, `:112-142` |
| Capture loop and detached stitching | `ScrollCaptureSession.swift:54-68` |
| Step messages | `ScrollCaptureSession.swift:91-104` |
| Finish and cancel | `ScrollCaptureSession.swift:72-89`, `AppDelegate.swift:191-195` |
| Matching and committing rows | `Sources/PinpointCore/ScrollStitcher.swift:46-99`, `:109-118` |
| Final image with sticky footer | `ScrollStitcher.swift:101-107` |

While a session is running, `capture(_:)` ignores every other capture request, so the stills modes wait until it ends (`AppDelegate.swift:124-125`). A frame that fails to capture pauses with a warning in the panel and the loop keeps trying (`ScrollCaptureSession.swift:62-65`). `lostTrack` leaves the stitched result as it was; scrolling back up to content the stitcher has already seen lets it pick up again.

## 3. Agent edit: prompt to undoable markup

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
| Guard, client creation | `Sources/Pinpoint/EditorModel.swift:307-310`, `:332-334`, `Sources/Pinpoint/AppSettings.swift:84-90`, `Sources/PinpointCore/LLM.swift:274-293` |
| runAI busy guard and error handling | `EditorModel.swift:363-373` |
| Analysis fallback | `EditorModel.swift:336-343` |
| Agent loop | `Sources/PinpointCore/Agent.swift:211-252` (`run`; `EditAgent` declared at `:205`) |
| Tool execution | `Agent.swift:83` (`AgentToolbox.execute`), tool specs at `Agent.swift:44` |
| Apply as one undoable step | `EditorModel.swift:349-357`, `:152-162` |
| Undo entry points | `Sources/Pinpoint/CanvasView.swift:272`, `Sources/Pinpoint/MainWindow.swift:138`, `:445` |

Cancellation: the stop button calls `cancelAI()` (`EditorModel.swift:361`), which cancels `agentTask`; the loop's `Task.checkCancellation()` throws `CancellationError`, which `runAI` swallows without logging an error. Name and tag changes from the agent are not part of the undo snapshot, which stores only `(annotations, crop)` (`EditorModel.swift:132-133`).

## 4. ChatGPT sign-in to first request

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
    account->>keychain: saveRegistration(...) and save(creds)
    alt either Keychain write fails
        account->>keychain: save(nil)
        account-->>settingsView: throws LLMError (couldn't save the sign-in)
    end
    account->>listener: stop() (defer)
    account-->>settingsView: ChatGPTCredentials
    settingsView->>account: cachedModels(refresh: true) via loadAutoPicks
    account->>account: accessToken(), still fresh
    account->>api: GET /v1/models with Bearer token
    api-->>settingsView: model list, status shows count

    Note over user,api: First AI request, for example the agent run in flow 3
    planClient->>account: autoModel(fast, excluding, refresh) when model is auto
    account-->>planClient: ModelPicker.best(cached list)
    planClient->>account: accessToken()
    opt expires within 60 s
        account->>oauth: postForm(tokenURL, refresh_token)
        oauth->>authServer: POST token
        account->>keychain: save refreshed credentials (failure logged with NSLog, token still used)
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
| Settings button and status | `Sources/Pinpoint/SettingsView.swift:172-190`, `:139-146` |
| PKCE, state, nonce, listener start | `Sources/PinpointCore/ChatGPTPlan.swift:153-160`, `:42-46`, `:265-271` |
| Authorize URL and browser open | `ChatGPTPlan.swift:161-163`, `:48-68` |
| Callback handling | `ChatGPTPlan.swift:305-326`, `:333-347` |
| Error, code and client id checks | `ChatGPTPlan.swift:164-173` |
| Token exchange, nonce and scope checks | `ChatGPTPlan.swift:174-185`, `:89-103` |
| Keychain storage | `ChatGPTPlan.swift:127-142`, `:190-193`, `Sources/PinpointCore/Assistants.swift:155-175` |
| Model list | `ChatGPTPlan.swift:238-248`, `:548-558` |
| Client creation for the first request | `Sources/Pinpoint/AppSettings.swift:84-90`, `Sources/PinpointCore/LLM.swift:275-279` |
| Auto model, token refresh, request | `ChatGPTPlan.swift:453-468`, `:198-229`, `:466-495`, `:560-564` |

A concurrent refresh is shared: `accessToken()` reuses one in-flight `refreshTask` under a lock (`ChatGPTPlan.swift:201-208`). A failed refresh surfaces as "Your ChatGPT sign-in expired" and does not clear the stored credentials (`ChatGPTPlan.swift:225-227`). The JWT is decoded without a signature check, as its doc comment states (`ChatGPTPlan.swift:70-78`).

## What these flows leave out

Drawing markup by hand on the canvas, voice notes, the library guide builder, export and handoff, the Codex CLI provider and the Anthropic or OpenAI-compatible request formats are not traced. None of these diagrams was checked by running the app; they are a reading of the source at the commit in [`README.md`](README.md).
