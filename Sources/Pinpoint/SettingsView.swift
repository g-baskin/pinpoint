import AppKit
import SwiftUI
import PinpointCore

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var keyDraft = ""
    @State private var models: [String] = []
    @State private var status = ""
    @State private var working = false
    @State private var signInTask: Task<Void, Never>?
    @State private var autoPick = ""
    @State private var autoFastPick = ""

    private var binding: Binding<ProviderSettings> {
        Binding(get: { settings.current }, set: { settings.providers[settings.provider] = $0 })
    }

    var body: some View {
        Form {
            Section("AI provider") {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(ProviderKind.allCases) { Text($0.displayName).tag($0) }
                }
                if settings.provider == .chatgpt { chatGPTRow }
                if settings.provider == .chatgpt { chatGPTModelRow } else {
                HStack {
                    TextField("Model", text: binding.model)
                    Menu("Fetch models") {
                        if models.isEmpty { Text("Press Refresh first") }
                        ForEach(models, id: \.self) { m in Button(m) { binding.wrappedValue.model = m } }
                        Divider()
                        Button("Refresh list") { fetchModels() }
                    }
                    .frame(width: 130)
                }
                }
                if settings.provider == .codex {
                    TextField("Codex path (blank = find automatically)", text: binding.baseURL)
                    Text("Uses OpenAI's Codex CLI signed in with your ChatGPT account (`codex login`). Slower than signing in directly.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if settings.provider != .chatgpt {
                    TextField("Base URL", text: binding.baseURL)
                }
                if settings.provider == .openrouter {
                    Text("Get a key at openrouter.ai/keys. Fetch models lists every model OpenRouter offers; pick one that supports images and tools.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if settings.provider.needsKey || settings.provider == .custom {
                    HStack {
                        SecureField(settings.apiKey(settings.provider).isEmpty ? "API key" : "API key saved in Keychain — paste to replace", text: $keyDraft)
                        Button("Save") { settings.setAPIKey(keyDraft, for: settings.provider); keyDraft = ""; status = "Key saved to Keychain." }
                            .disabled(keyDraft.isEmpty)
                    }
                }
                if settings.provider == .ollama {
                    Text("Runs on your Mac with no key. Install Ollama and pull a vision model, e.g. `ollama pull qwen2.5vl`.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button("Test connection") { test() }.disabled(working)
                    if working { ProgressView().controlSize(.small) }
                    Text(status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Section("After each capture") {
                Toggle("Copy to clipboard", isOn: $settings.copyAfterCapture)
                Toggle("Open in editor", isOn: $settings.openEditorAfterCapture)
                Toggle("Auto-blur sensitive info (on-device)", isOn: $settings.autoRedactOnCapture)
                TextField("Always redact these words (comma separated, e.g. Storewren, Acme Corp)", text: $settings.customRedactTerms, axis: .vertical)
                    .lineLimit(1...3)
                Text("Auto-redact covers emails, API keys & tokens, account / ad IDs (Meta act_…, pixel IDs, Stripe, Google Ads/Analytics), phone & card numbers, IP addresses, SSNs, faces, and these words.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Name & tag with AI", isOn: $settings.autoNameWithAI)
            }
            Section("Voice notes") {
                Toggle("After drawing an arrow or shape, ask “Add more context?”", isOn: $settings.askForContext)
                Picker("Dictation", selection: $settings.dictationSource) {
                    Text("Auto — use my dictation app if it's running").tag("auto")
                    Text("Always Pinpoint' built-in dictation").tag("builtin")
                }
                if let ext = ExternalDictation.running(), settings.dictationSource != "builtin" {
                    Label("\(ext.name) is running — \(ext.hint.prefix(1).lowercased() + ext.hint.dropFirst()). It types straight into the note box.",
                          systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                } else {
                    Text("No dictation app detected (Wispr Flow, Superwhisper, Aqua Voice…), so Pinpoint uses Apple's on-device dictation.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Built-in: start listening when the prompt opens (say “yes” and talk, or “no”)", isOn: $settings.listenOnPrompt)
                Picker("Built-in microphone", selection: $settings.micUID) {
                    Text("System default\(AudioInputs.systemDefault().map { " (\($0.name))" } ?? "")").tag("")
                    ForEach(AudioInputs.all()) { d in Text(d.name).tag(d.uid) }
                }
                Text("Built-in speech is turned into text on this Mac. Hold ⌥ or the mic button for push-to-talk (when no dictation app uses ⌥). Press M for the Voice Note tool.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Displays") { DisplaysList() }
            Section("Shortcuts") {
                LabeledContent("Capture area / window", value: "⌃⇧1")
                LabeledContent("Capture window", value: "⌃⇧2")
                LabeledContent("Capture full screen (screen under mouse)", value: "⌃⇧3")
                LabeledContent("Capture all screens", value: "⌃⇧4")
                LabeledContent("Open library", value: "⌃⇧L")
            }
            Section("Library") {
                LabeledContent("Folder", value: LibraryStore.defaultRoot.path)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .onChange(of: settings.provider) { _, _ in models = []; status = ""; keyDraft = "" }
    }

    /// Auto (recommended) or a specific model from the plan.
    @ViewBuilder private var chatGPTModelRow: some View {
        let current = settings.current.model
        Picker("Model", selection: Binding(
            get: { ModelPicker.isAuto(current) ? ModelPicker.auto : current },
            set: { binding.wrappedValue.model = $0 }
        )) {
            Text("Auto — best for Pinpoint (recommended)").tag(ModelPicker.auto)
            if !models.isEmpty { Divider() }
            ForEach(ModelPicker.ranked(models) + models.filter { ModelPicker.score($0) == nil }, id: \.self) { m in
                Text(m).tag(m)
            }
            if !ModelPicker.isAuto(current) && !models.contains(current) { Text(current).tag(current) }
        }
        if ModelPicker.isAuto(current) && ChatGPTAccount.shared.isSignedIn {
            Text(autoPick.isEmpty ? "Checking your plan's models…" : "Auto is using **\(autoPick)** for edits and **\(autoFastPick)** for quick naming. It re-checks daily, so new models are picked up automatically.")
                .font(.caption).foregroundStyle(.secondary)
                .task(id: ChatGPTAccount.shared.isSignedIn) { await loadAutoPicks(refresh: false) }
        }
    }

    private func loadAutoPicks(refresh: Bool) async {
        do {
            let list = try await ChatGPTAccount.shared.cachedModels(refresh: refresh)
            models = list
            autoPick = ModelPicker.best(list) ?? "none"
            autoFastPick = ModelPicker.best(list, fast: true) ?? autoPick
        } catch { status = error.localizedDescription }
    }

    @ViewBuilder private var chatGPTRow: some View {
        let account = ChatGPTAccount.shared
        if account.isSignedIn {
            HStack {
                Label("Signed in\(account.email.map { " as \($0)" } ?? "")", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                Spacer()
                Button("Sign out") {
                    Task { await account.signOut(); settings.touch(); status = "Signed out." }
                }
            }
        } else {
            HStack {
                Button { signIn() } label: { Label("Sign in with ChatGPT", systemImage: "person.crop.circle.badge.checkmark") }
                    .controlSize(.large).disabled(signInTask != nil)
                if signInTask != nil {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { signInTask?.cancel(); signInTask = nil }
                }
            }
            Text("Opens your browser. Sign in to ChatGPT and allow “Use your ChatGPT plan” for Pinpoint. AI requests then use your plan's limits, not an API key.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func signIn() {
        status = "Waiting for you to finish signing in in your browser…"
        signInTask = Task {
            do {
                _ = try await ChatGPTAccount.shared.signIn { url in DispatchQueue.main.async { NSWorkspace.shared.open(url) } }
                NSApp.activate(ignoringOtherApps: true)
                status = "Signed in. Loading your models…"
                settings.touch()
                await loadAutoPicks(refresh: true)
                status = "Signed in ✓ — \(models.count) models on your plan."
            } catch is CancellationError {
                status = "Sign-in cancelled."
            } catch {
                status = error.localizedDescription
            }
            signInTask = nil
            settings.touch()
        }
    }

    private func fetchModels() {
        working = true; status = ""
        let s = settings.current, key = settings.apiKey(s.kind)
        Task {
            do { models = try await s.listModels(apiKey: key); status = "Found \(models.count) models." }
            catch { status = error.localizedDescription }
            working = false
        }
    }

    private func test() {
        working = true; status = ""
        Task {
            do {
                let c = try settings.makeClient()
                let r = try await c.ask(system: "", prompt: "Reply with the single word: ready", maxTokens: 20)
                status = "Connected ✓ (\(r.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30)))"
            } catch { status = error.localizedDescription }
            working = false
        }
    }
}

/// Lists the connected displays (updates when monitors are plugged in or rearranged).
struct DisplaysList: View {
    @State private var tick = 0
    var body: some View {
        let screens = NSScreen.screens
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(screens.enumerated()), id: \.offset) { i, s in
                HStack {
                    Image(systemName: i == 0 ? "display" : "display.2")
                    Text(s.localizedName)
                    Spacer()
                    Text("\(Int(s.frame.width * s.backingScaleFactor))×\(Int(s.frame.height * s.backingScaleFactor)) px @\(Int(s.backingScaleFactor))x\(i == 0 ? " • main" : "")")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            Text(screens.count > 1 ? "\(screens.count) displays detected. ⌃⇧1 shows the picker on every screen; ⌃⇧4 captures them all as one image." : "1 display detected.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .id(tick)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in tick += 1 }
    }
}
