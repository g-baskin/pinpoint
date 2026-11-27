import CryptoKit
import Foundation
import Network

// "Sign in with ChatGPT": OpenAI's agent sign-in that lets an app use the user's ChatGPT plan through the OpenAI API.
// Flow: PKCE + dynamic app registration ("Pinpoint") at auth.openai.com, loopback callback on 127.0.0.1:1455,
// tokens kept in the Keychain and refreshed automatically. Requests go to https://api.openai.com/v1/responses.

public struct ChatGPTCredentials: Codable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Date
    public var clientId: String
    public var subject: String
    public var email: String?
    public var idToken: String?
}

public enum ChatGPTOAuth {
    public static let issuer = "https://auth.openai.com"
    public static let authorizeURL = "\(issuer)/api/accounts/authorize"
    public static let tokenURL = "\(issuer)/api/accounts/oauth/token"
    public static let revokeURL = "\(issuer)/api/accounts/oauth/revoke"
    public static let registrationClientId = "dynamic_agent_client"
    public static let agentName = "Pinpoint"
    public static let resource = "https://api.openai.com/v1"
    public static let planScope = "chatgpt.tokens.use.direct"
    public static let scopes = "openid profile email offline_access resource.invoke \(planScope)"
    public static let apiBase = "https://api.openai.com/v1"
    public static let callbackPath = "/auth/callback"
    public static let preferredPort: UInt16 = 1455

    public static func base64url(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    public static func randomBytes(_ n: Int) -> Data {
        var g = SystemRandomNumberGenerator()
        return Data((0..<n).map { _ in UInt8.random(in: 0...255, using: &g) })
    }

    public static func pkce() -> (verifier: String, challenge: String) {
        let verifier = base64url(randomBytes(32))
        let challenge = base64url(Data(SHA256.hash(data: Data(verifier.utf8))))
        return (verifier, challenge)
    }

    public static func authorizeRequestURL(clientId: String?, hostId: String, email: String?, redirectURI: String,
                                           state: String, nonce: String, challenge: String) -> URL {
        var c = URLComponents(string: authorizeURL)!
        var q: [URLQueryItem] = [URLQueryItem(name: "client_id", value: clientId ?? registrationClientId)]
        if clientId == nil { q.append(URLQueryItem(name: "agent_name_hint", value: agentName)) }
        q.append(URLQueryItem(name: "ext_agent_host_id", value: hostId))
        if let email { q.append(URLQueryItem(name: "login_hint", value: email)) }
        q += [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "resource", value: resource),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
        ]
        c.queryItems = q
        // URLComponents leaves "+" and spaces handled; scope spaces become %20 which the server accepts.
        return c.url!
    }

    /// Decodes a JWT payload (no signature check — the token came straight from auth.openai.com over TLS).
    public static func jwtClaims(_ token: String) -> JSONValue? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var s = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        guard let d = Data(base64Encoded: s) else { return nil }
        return try? JSONValue.parse(d)
    }

    static func formBody(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = fields.sorted { $0.key < $1.key }.map { k, v in
            "\(k)=\(v.addingPercentEncoding(withAllowedCharacters: allowed) ?? v)"
        }.joined(separator: "&")
        return Data(body.utf8)
    }

    static func postForm(_ url: String, _ fields: [String: String]) async throws -> JSONValue {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formBody(fields)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let j = (try? JSONValue.parse(data)) ?? .null
        guard (200..<300).contains(code) else {
            let reason = j["error_description"]?.stringValue ?? j["error"]?.stringValue ?? String(decoding: data.prefix(300), as: UTF8.self)
            throw LLMError("ChatGPT sign-in failed (\(code)): \(reason)")
        }
        return j
    }
}

/// Stores credentials + app registration and performs sign-in, refresh and sign-out.
public final class ChatGPTAccount: @unchecked Sendable {
    public static let shared = ChatGPTAccount()
    private let lock = NSLock()
    private let credsKey = "chatgpt.credentials"
    private let regKey = "chatgpt.registration"
    private var cached: ChatGPTCredentials?
    private var refreshTask: Task<ChatGPTCredentials, Error>?

    struct Registration: Codable { var clientId: String; var subject: String; var email: String? }

    public var credentials: ChatGPTCredentials? {
        lock.lock(); defer { lock.unlock() }
        if cached == nil, let d = Keychain.get(credsKey).data(using: .utf8) {
            cached = try? JSONDecoder().decode(ChatGPTCredentials.self, from: d)
        }
        return cached
    }
    public var isSignedIn: Bool { credentials != nil }
    public var email: String? { credentials?.email }

    @discardableResult
    private func save(_ c: ChatGPTCredentials?) -> Bool {
        lock.lock(); cached = c; lock.unlock()
        guard let c else { return Keychain.set("", for: credsKey) }
        guard let d = try? JSONEncoder().encode(c) else { return false }
        return Keychain.set(String(decoding: d, as: UTF8.self), for: credsKey)
    }

    private var registration: Registration? {
        Keychain.get(regKey).data(using: .utf8).flatMap { try? JSONDecoder().decode(Registration.self, from: $0) }
    }

    private func saveRegistration(_ r: Registration) -> Bool {
        guard let d = try? JSONEncoder().encode(r) else { return false }
        return Keychain.set(String(decoding: d, as: UTF8.self), for: regKey)
    }

    private var hostId: String {
        let key = "chatgptHostId"
        if let v = UserDefaults.standard.string(forKey: key), v.hasPrefix("urn:uuid:") { return v }
        let v = "urn:uuid:\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(v, forKey: key)
        return v
    }

    /// Full browser sign-in. `open` is called with the URL to show (the app opens the default browser).
    public func signIn(open: @escaping @Sendable (URL) -> Void) async throws -> ChatGPTCredentials {
        let reg = registration
        let (verifier, challenge) = ChatGPTOAuth.pkce()
        let state = ChatGPTOAuth.randomBytes(16).map { String(format: "%02x", $0) }.joined()
        let nonce = ChatGPTOAuth.randomBytes(16).map { String(format: "%02x", $0) }.joined()
        let listener = try await LoopbackListener.start(expectedState: state, allowAnyPort: reg != nil)
        defer { listener.stop() }
        let redirect = "http://127.0.0.1:\(listener.port)\(ChatGPTOAuth.callbackPath)"
        let url = ChatGPTOAuth.authorizeRequestURL(clientId: reg?.clientId, hostId: hostId, email: reg?.email,
                                                   redirectURI: redirect, state: state, nonce: nonce, challenge: challenge)
        open(url)
        let params = try await listener.waitForCallback(timeout: 180)
        if let err = params["error"] {
            if err == "access_denied" { throw LLMError("ChatGPT plan use wasn't allowed. Sign in again and choose “Allow” for “Use your ChatGPT plan”.") }
            throw LLMError("ChatGPT sign-in failed: \(params["error_description"] ?? err)")
        }
        guard let code = params["code"] else { throw LLMError("ChatGPT sign-in returned no code.") }
        let issued = params["client_id"]
        guard let clientId = reg?.clientId ?? issued, clientId != ChatGPTOAuth.registrationClientId else {
            throw LLMError("ChatGPT didn't finish registering Pinpoint. Try signing in again.")
        }
        let tok = try await ChatGPTOAuth.postForm(ChatGPTOAuth.tokenURL, [
            "grant_type": "authorization_code", "client_id": clientId, "code": code,
            "code_verifier": verifier, "redirect_uri": redirect, "resource": ChatGPTOAuth.resource,
        ])
        guard let access = tok["access_token"]?.stringValue, let refresh = tok["refresh_token"]?.stringValue,
              let idToken = tok["id_token"]?.stringValue else { throw LLMError("ChatGPT sign-in returned no tokens.") }
        let scopes = (tok["scope"]?.stringValue ?? "").split(separator: " ").map(String.init)
        let claims = ChatGPTOAuth.jwtClaims(idToken)
        if let n = claims?["nonce"]?.stringValue, n != nonce { throw LLMError("ChatGPT sign-in failed a security check (nonce). Try again.") }
        guard scopes.contains(ChatGPTOAuth.planScope) else {
            throw LLMError("Signed in, but “Use your ChatGPT plan” wasn't allowed. Sign in again and allow it.")
        }
        let creds = ChatGPTCredentials(accessToken: access, refreshToken: refresh,
                                       expiresAt: Date().addingTimeInterval(tok["expires_in"]?.doubleValue ?? 3600),
                                       clientId: clientId, subject: claims?["sub"]?.stringValue ?? "",
                                       email: claims?["email"]?.stringValue, idToken: idToken)
        guard saveRegistration(Registration(clientId: clientId, subject: creds.subject, email: creds.email)), save(creds) else {
            save(nil)
            throw LLMError("Signed in, but Pinpoint couldn't save the sign-in to your Keychain. Check Keychain Access and try again.")
        }
        return creds
    }

    /// A valid access token, refreshing when it's within a minute of expiry.
    public func accessToken() async throws -> String {
        guard let c = credentials else { throw LLMError("Sign in with ChatGPT in Pinpoint Settings first.") }
        if c.expiresAt.timeIntervalSinceNow > 60 { return c.accessToken }
        let task: Task<ChatGPTCredentials, Error> = lock.withLock {
            if let t = refreshTask { return t }
            let t = Task { try await self.refresh(c) }
            refreshTask = t
            return t
        }
        defer { lock.withLock { refreshTask = nil } }
        return try await task.value.accessToken
    }

    private func refresh(_ c: ChatGPTCredentials) async throws -> ChatGPTCredentials {
        do {
            let tok = try await ChatGPTOAuth.postForm(ChatGPTOAuth.tokenURL, [
                "grant_type": "refresh_token", "client_id": c.clientId, "refresh_token": c.refreshToken, "resource": ChatGPTOAuth.resource,
            ])
            guard let access = tok["access_token"]?.stringValue else { throw LLMError("ChatGPT token refresh returned no token.") }
            var n = c
            n.accessToken = access
            n.refreshToken = tok["refresh_token"]?.stringValue ?? c.refreshToken
            n.expiresAt = Date().addingTimeInterval(tok["expires_in"]?.doubleValue ?? 3600)
            if let id = tok["id_token"]?.stringValue { n.idToken = id }
            // The refreshed token still works for this session; only the next launch would need a new sign-in.
            if !save(n) { NSLog("Pinpoint: couldn't save refreshed ChatGPT sign-in to Keychain") }
            return n
        } catch {
            throw LLMError("Your ChatGPT sign-in expired. Sign in again in Settings. (\(error.localizedDescription))")
        }
    }

    public func signOut() async {
        if let c = credentials {
            _ = try? await ChatGPTOAuth.postForm(ChatGPTOAuth.revokeURL, ["token": c.refreshToken, "token_type_hint": "refresh_token", "client_id": c.clientId])
        }
        save(nil)
    }

    /// Models available on the user's plan.
    public func models() async throws -> [String] {
        let token = try await accessToken()
        var req = URLRequest(url: URL(string: "\(ChatGPTOAuth.apiBase)/models")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 30
        let j = try JSONValue.parse(try await perform(req, session: .shared))
        if let list = j["models"]?.arrayValue {
            return list.filter { ($0["visibility"]?.stringValue ?? "list") == "list" }.compactMap { $0["slug"]?.stringValue }
        }
        return (j["data"]?.arrayValue ?? []).compactMap { $0["id"]?.stringValue }.sorted()
    }
}

/// Minimal one-shot HTTP server on 127.0.0.1 that captures the OAuth redirect.
final class LoopbackListener: @unchecked Sendable {
    let listener: NWListener
    let port: UInt16
    private let expectedState: String
    private var continuation: CheckedContinuation<[String: String], Error>?
    private var result: Result<[String: String], Error>?
    private let lock = NSLock()

    private init(listener: NWListener, port: UInt16, expectedState: String) {
        self.listener = listener; self.port = port; self.expectedState = expectedState
    }

    static func start(expectedState: String, allowAnyPort: Bool) async throws -> LoopbackListener {
        var lastError: Error = LLMError("Could not start the local sign-in listener.")
        for p in allowAnyPort ? [ChatGPTOAuth.preferredPort, 0] : [ChatGPTOAuth.preferredPort] {
            do { return try await make(port: p, expectedState: expectedState) } catch { lastError = error }
        }
        throw LLMError("Port 1455 is busy (another sign-in may be open, e.g. in GG Coder or Codex). Close it and try again. \(lastError.localizedDescription)")
    }

    /// Startup state for `make`; only touched from the listener's serial queue.
    private final class StartState: @unchecked Sendable {
        var resumed = false
        var holder: LoopbackListener?
    }

    private static func make(port: UInt16, expectedState: String) async throws -> LoopbackListener {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port) ?? .any)
        params.allowLocalEndpointReuse = true
        let l = try NWListener(using: params)
        let queue = DispatchQueue(label: "pinpoint.oauth")
        return try await withCheckedThrowingContinuation { cont in
            let start = StartState()
            l.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard !start.resumed, let actual = l.port?.rawValue else { return }
                    start.resumed = true
                    let ll = LoopbackListener(listener: l, port: actual, expectedState: expectedState)
                    start.holder = ll
                    l.newConnectionHandler = { conn in ll.handle(conn, queue: queue) }
                    cont.resume(returning: ll)
                case .failed(let e):
                    if !start.resumed { start.resumed = true; cont.resume(throwing: e) } else { start.holder?.finish(.failure(e)) }
                default: break
                }
            }
            l.newConnectionHandler = { $0.cancel() }
            l.start(queue: queue)
        }
    }

    private func handle(_ conn: NWConnection, queue: DispatchQueue) {
        conn.start(queue: queue)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, _, _ in
            guard let self, let data, let req = String(data: data, encoding: .utf8),
                  let line = req.split(separator: "\r\n").first else { conn.cancel(); return }
            let parts = line.split(separator: " ")
            let target = parts.count > 1 ? String(parts[1]) : "/"
            let comps = URLComponents(string: "http://127.0.0.1\(target)")
            var status = "404 Not Found", body = "Not found"
            if comps?.path == ChatGPTOAuth.callbackPath {
                var q: [String: String] = [:]
                for item in comps?.queryItems ?? [] { q[item.name] = item.value ?? "" }
                if q["state"] == self.expectedState {
                    status = "200 OK"
                    body = "<html><body style='font:16px -apple-system;text-align:center;padding-top:80px'><h1>You're signed in to Pinpoint.</h1><p>You can close this tab.</p></body></html>"
                    self.finish(.success(q))
                } else { status = "400 Bad Request"; body = "State mismatch" }
            }
            let resp = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
            conn.send(content: Data(resp.utf8), completion: .contentProcessed { _ in conn.cancel() })
        }
    }

    fileprivate func finish(_ r: Result<[String: String], Error>) {
        lock.lock()
        if result != nil { lock.unlock(); return }
        result = r
        let c = continuation; continuation = nil
        lock.unlock()
        c?.resume(with: r)
    }

    func waitForCallback(timeout: TimeInterval) async throws -> [String: String] {
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.finish(.failure(LLMError("Sign-in timed out. Try again.")))
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                lock.lock()
                if let r = result { lock.unlock(); cont.resume(with: r); return }
                continuation = cont
                lock.unlock()
            }
        } onCancel: { [weak self] in
            self?.finish(.failure(LLMError("ChatGPT sign-in was cancelled.")))
        }
    }

    func stop() { listener.cancel() }
}

/// Talks to the OpenAI Responses API with the ChatGPT-plan access token (streaming, tools in a namespace).
public struct ChatGPTPlanClient: LLMClient {
    public var model: String
    public var account: ChatGPTAccount
    public static let toolNamespace = "pinpoint"

    public init(model: String, account: ChatGPTAccount = .shared) { self.model = model; self.account = account }

    static func usesLite(_ m: String) -> Bool { m.hasPrefix("gpt-5.6-") || m.hasPrefix("gpt-6-") || m.hasPrefix("gpt-6.") }

    public static func makeBody(model: String, system: String, messages: [ChatMessage], tools: [ToolSpec]) -> JSONValue {
        var input: [JSONValue] = []
        for m in messages {
            var content: [JSONValue] = []
            func flush() {
                guard !content.isEmpty else { return }
                input.append(["type": "message", "role": .string(m.role.rawValue), "content": .array(content)])
                content = []
            }
            for p in m.parts {
                switch p {
                case .text(let t):
                    content.append(m.role == .user ? ["type": "input_text", "text": .string(t)] : ["type": "output_text", "text": .string(t)])
                case .image(let png):
                    content.append(["type": "input_image", "detail": "auto", "image_url": .string("data:image/png;base64," + png.base64EncodedString())])
                case .toolUse(let id, let name, let args):
                    flush()
                    input.append(["type": "function_call", "call_id": .string(id), "name": .string(name),
                                  "namespace": .string(toolNamespace), "arguments": .string(args.jsonString)])
                case .toolResult(let id, let out, _):
                    flush()
                    input.append(["type": "function_call_output", "call_id": .string(id), "output": .string(out.isEmpty ? "(empty)" : out)])
                }
            }
            flush()
        }
        let lite = usesLite(model)
        var body: [String: JSONValue] = [
            "model": .string(model), "store": false, "stream": true, "instructions": .string(system),
            "input": .array(input), "parallel_tool_calls": true, "include": ["reasoning.encrypted_content"],
            "reasoning": ["effort": .string(lite ? "low" : "none"), "summary": "auto"],
            "prompt_cache_key": "pinpoint",
        ]
        if lite { body["text"] = ["verbosity": "low"] }
        if !tools.isEmpty {
            body["tool_choice"] = "auto"
            body["tools"] = [[
                "type": "namespace", "name": .string(toolNamespace), "description": "Pinpoint screenshot editing tools.",
                "tools": .array(tools.map { ["type": "function", "name": .string($0.name), "description": .string($0.description),
                                             "parameters": $0.parameters, "strict": false] }),
            ]]
        }
        return .object(body)
    }

    /// Folds Responses API stream events into a ChatResponse.
    public static func collect(events: [JSONValue]) throws -> ChatResponse {
        var text = ""
        var calls: [(String, String, String)] = []
        var seen = Set<String>()
        func addCall(_ item: JSONValue) {
            guard item["type"]?.stringValue == "function_call" else { return }
            let id = item["call_id"]?.stringValue ?? item["id"]?.stringValue ?? UUID().uuidString
            guard !seen.contains(id) else { return }
            seen.insert(id)
            var name = item["name"]?.stringValue ?? ""
            if name.hasPrefix(toolNamespace + ".") { name.removeFirst(toolNamespace.count + 1) }
            calls.append((id, name, item["arguments"]?.stringValue ?? "{}"))
        }
        var completedText: String?
        for e in events {
            switch e["type"]?.stringValue {
            case "response.output_text.delta": text += e["delta"]?.stringValue ?? ""
            case "response.output_item.done": if let item = e["item"] { addCall(item) }
            case "response.completed", "response.done", "response.incomplete":
                var t = ""
                for item in e["response"]?["output"]?.arrayValue ?? [] {
                    addCall(item)
                    if item["type"]?.stringValue == "message" {
                        for c in item["content"]?.arrayValue ?? [] where c["type"]?.stringValue == "output_text" { t += c["text"]?.stringValue ?? "" }
                    }
                }
                if !t.isEmpty { completedText = t }
            case "response.failed", "error":
                let msg = e["error"]?["message"]?.stringValue ?? e["response"]?["error"]?["message"]?.stringValue ?? e["message"]?.stringValue ?? "ChatGPT request failed."
                throw LLMError(msg)
            default: break
            }
        }
        if text.isEmpty, let t = completedText { text = t }
        var parts: [ChatPart] = text.isEmpty ? [] : [.text(text)]
        for (id, name, args) in calls {
            parts.append(.toolUse(id: id, name: name, input: (try? JSONValue.parse(args)) ?? [:]))
        }
        return ChatResponse(parts: parts, stopReason: calls.isEmpty ? "end_turn" : "tool_use")
    }

    public func send(system: String, messages: [ChatMessage], tools: [ToolSpec], maxTokens: Int) async throws -> ChatResponse {
        guard ModelPicker.isAuto(model) else { return try await send(model: model, system: system, messages: messages, tools: tools) }
        // Auto: best model on the plan; if the plan refuses it, refresh the list and fall back to the next best.
        let fast = model.lowercased() == ModelPicker.autoFast
        var tried = Set<String>()
        var lastError: Error = LLMError("No model available.")
        for attempt in 0..<3 {
            let m = try await account.autoModel(fast: fast, excluding: tried, refresh: attempt > 0)
            tried.insert(m)
            do { return try await send(model: m, system: system, messages: messages, tools: tools) }
            catch let e as LLMError where e.message.contains("HTTP 404") || e.message.contains("HTTP 400") && e.message.lowercased().contains("model") {
                lastError = e
            }
        }
        throw lastError
    }

    func send(model: String, system: String, messages: [ChatMessage], tools: [ToolSpec]) async throws -> ChatResponse {
        let token = try await account.accessToken()
        var req = URLRequest(url: URL(string: "\(ChatGPTOAuth.apiBase)/responses")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 300
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("Pinpoint/0.3 (macOS)", forHTTPHeaderField: "User-Agent")
        req.httpBody = Self.makeBody(model: model, system: system, messages: messages, tools: tools).data()
        let (bytes, resp) = try await URLSession.shared.bytes(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if !(200..<300).contains(code) {
            var raw = Data()
            for try await b in bytes { raw.append(b); if raw.count > 8000 { break } }
            let j = try? JSONValue.parse(raw)
            var msg = j?["error"]?["message"]?.stringValue ?? String(decoding: raw.prefix(400), as: UTF8.self)
            if code == 404 && msg.contains("does not exist") { msg = "The model “\(model)” isn't available on your ChatGPT plan. Pick another in Settings → Fetch models." }
            if code == 429 { msg = "ChatGPT plan limit reached: \(msg) (see chatgpt.com/settings/usage)" }
            throw LLMError("ChatGPT HTTP \(code): \(msg)")
        }
        var events: [JSONValue] = []
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload.isEmpty || payload == "[DONE]" { continue }
            if let j = try? JSONValue.parse(payload) { events.append(j) }
        }
        return try Self.collect(events: events)
    }
}

/// Picks the best model for Pinpoint from a provider's list: needs vision + reliable tool use + reasonable speed.
public enum ModelPicker {
    public static let auto = "auto"
    public static let autoFast = "auto-fast"

    public static func isAuto(_ m: String) -> Bool {
        let t = m.trimmingCharacters(in: .whitespaces).lowercased()
        return t.isEmpty || t == auto || t == autoFast || t.hasPrefix("auto ")
    }

    /// Higher is better; nil = not suitable (audio, images-only, embeddings, ...).
    public static func score(_ id: String, fast: Bool = false) -> Double? {
        let s = id.lowercased()
        let banned = ["audio", "realtime", "tts", "transcribe", "whisper", "embedding", "image", "dall", "search", "moderation",
                      "oss", "instruct", "babbage", "davinci", "computer-use", "deep-research", "sora"]
        if banned.contains(where: { s.contains($0) }) { return nil }
        var base: Double
        if let m = s.range(of: #"gpt-(\d+)(?:\.(\d+))?(o)?"#, options: .regularExpression) {
            let nums = s[m].dropFirst(4).split(whereSeparator: { !$0.isNumber }).compactMap { Double($0) }
            base = (nums.first ?? 0) * 100 + (nums.count > 1 ? nums[1] * 10 : 0)
            if s[m].hasSuffix("o") { base += 5 }   // gpt-4o
        } else if let m = s.range(of: #"^o(\d+)"#, options: .regularExpression) {
            base = 300 + (Double(s[m].dropFirst()) ?? 0) * 10   // o-series reasoning: capable but slow
            base -= 60
        } else {
            return nil
        }
        if s.contains("pro") { base -= 40 }           // very slow / heavy
        if s.contains("nano") { base -= fast ? 10 : 30 }
        if s.contains("mini") { base += fast ? 15 : -9 }
        if s.contains("codex") { base -= 15 }         // tuned for code, not screenshots
        if s.contains("chat-latest") || s.contains("preview") { base -= 4 }
        if s.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil { base -= 1 }   // prefer the alias
        return base
    }

    public static func ranked(_ ids: [String], fast: Bool = false) -> [String] {
        ids.compactMap { id in score(id, fast: fast).map { (id, $0) } }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.count < $1.0.count }
            .map(\.0)
    }

    public static func best(_ ids: [String], fast: Bool = false) -> String? { ranked(ids, fast: fast).first }
}

extension ChatGPTAccount {
    private static let cacheKey = "chatgptModelCache"
    private static let cacheDateKey = "chatgptModelCacheDate"

    /// The plan's model list, cached for a day.
    public func cachedModels(refresh: Bool = false) async throws -> [String] {
        let d = UserDefaults.standard
        if !refresh, let list = d.stringArray(forKey: Self.cacheKey), !list.isEmpty,
           let at = d.object(forKey: Self.cacheDateKey) as? Date, Date().timeIntervalSince(at) < 86_400 {
            return list
        }
        let list = try await models()
        d.set(list, forKey: Self.cacheKey)
        d.set(Date(), forKey: Self.cacheDateKey)
        return list
    }

    public func autoModel(fast: Bool = false, excluding: Set<String> = [], refresh: Bool = false) async throws -> String {
        let list = try await cachedModels(refresh: refresh).filter { !excluding.contains($0) }
        guard let m = ModelPicker.best(list, fast: fast) else { throw LLMError("No suitable model found on your ChatGPT plan.") }
        return m
    }
}
