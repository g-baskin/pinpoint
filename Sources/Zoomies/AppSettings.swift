import Foundation
import ZoomiesCore

/// User preferences (UserDefaults) + API keys (Keychain).
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    @Published var provider: ProviderKind { didSet { d.set(provider.rawValue, forKey: "provider") } }
    @Published var providers: [ProviderKind: ProviderSettings] { didSet { saveProviders() } }
    @Published var autoNameWithAI: Bool { didSet { d.set(autoNameWithAI, forKey: "autoNameWithAI") } }
    @Published var copyAfterCapture: Bool { didSet { d.set(copyAfterCapture, forKey: "copyAfterCapture") } }
    @Published var openEditorAfterCapture: Bool { didSet { d.set(openEditorAfterCapture, forKey: "openEditorAfterCapture") } }
    @Published var autoRedactOnCapture: Bool { didSet { d.set(autoRedactOnCapture, forKey: "autoRedactOnCapture") } }
    /// After drawing an arrow/shape, pop up "Add more context?".
    @Published var askForContext: Bool { didSet { d.set(askForContext, forKey: "askForContext") } }
    /// Start listening as soon as that prompt opens (say "yes" and talk, or "no" to dismiss).
    @Published var listenOnPrompt: Bool { didSet { d.set(listenOnPrompt, forKey: "listenOnPrompt") } }
    /// "auto" = use a running dictation app (Wispr Flow, …) if there is one, else built-in; "external"; "builtin".
    @Published var dictationSource: String { didSet { d.set(dictationSource, forKey: "dictationSource") } }
    /// CoreAudio UID of the mic for built-in dictation; "" = system default input.
    @Published var micUID: String { didSet { d.set(micUID, forKey: "micUID") } }
    /// Comma-separated words/phrases auto-redact always covers (client names, store names, project codes…).
    @Published var customRedactTerms: String { didSet { d.set(customRedactTerms, forKey: "customRedactTerms") } }
    var redactTerms: [String] {
        customRedactTerms.split(whereSeparator: { $0 == "," || $0 == "\n" }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count >= 2 }
    }

    /// The dictation app to defer to right now, if any.
    var activeExternalDictation: ExternalDictation? {
        dictationSource == "builtin" ? nil : ExternalDictation.running()
    }

    private init() {
        provider = ProviderKind(rawValue: d.string(forKey: "provider") ?? "") ?? .chatgpt
        var map: [ProviderKind: ProviderSettings] = [:]
        if let data = d.data(forKey: "providers"), let list = try? JSONDecoder().decode([ProviderSettings].self, from: data) {
            for p in list { map[p.kind] = p }
        }
        for k in ProviderKind.allCases where map[k] == nil { map[k] = ProviderSettings(kind: k) }
        // One-time: ChatGPT defaults to Auto (the user asked Pinpoint to choose the best model).
        if !d.bool(forKey: "chatgptAutoMigrated") {
            map[.chatgpt]?.model = ModelPicker.auto
            d.set(true, forKey: "chatgptAutoMigrated")
        }
        providers = map
        autoNameWithAI = d.object(forKey: "autoNameWithAI") as? Bool ?? true
        copyAfterCapture = d.object(forKey: "copyAfterCapture") as? Bool ?? true
        openEditorAfterCapture = d.object(forKey: "openEditorAfterCapture") as? Bool ?? true
        autoRedactOnCapture = d.object(forKey: "autoRedactOnCapture") as? Bool ?? false
        askForContext = d.object(forKey: "askForContext") as? Bool ?? true
        listenOnPrompt = d.object(forKey: "listenOnPrompt") as? Bool ?? true
        dictationSource = d.string(forKey: "dictationSource") ?? "auto"
        micUID = d.string(forKey: "micUID") ?? ""
        customRedactTerms = d.string(forKey: "customRedactTerms") ?? ""
    }

    private func saveProviders() {
        if let data = try? JSONEncoder().encode(Array(providers.values)) { d.set(data, forKey: "providers") }
    }

    var current: ProviderSettings { providers[provider] ?? ProviderSettings(kind: provider) }

    func apiKey(_ k: ProviderKind) -> String { Keychain.get(k.rawValue) }
    func setAPIKey(_ v: String, for k: ProviderKind) { Keychain.set(v.trimmingCharacters(in: .whitespacesAndNewlines), for: k.rawValue); objectWillChange.send() }

    var isAIConfigured: Bool {
        switch current.kind {
        case .chatgpt: return ChatGPTAccount.shared.isSignedIn
        case .codex: return CodexClient.locate(current.baseURL) != nil
        default: return !current.kind.needsKey || !apiKey(current.kind).isEmpty
        }
    }

    /// Bump to refresh views after sign-in state changes.
    func touch() { objectWillChange.send() }

    /// `fast`: quick background jobs (naming/tagging). With ChatGPT on Auto that picks the newest "mini" model.
    func makeClient(fast: Bool = false) throws -> LLMClient {
        if fast, current.kind == .chatgpt, ModelPicker.isAuto(current.model) {
            guard ChatGPTAccount.shared.isSignedIn else { throw LLMError("Sign in with ChatGPT in Settings first.") }
            return ChatGPTPlanClient(model: ModelPicker.autoFast)
        }
        return try current.makeClient(apiKey: apiKey(current.kind))
    }
}
