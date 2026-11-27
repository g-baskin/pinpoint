import Foundation

/// Uses the user's ChatGPT subscription through OpenAI's own Codex CLI (`codex exec`), signed in with "Sign in with ChatGPT".
/// Codex has no tool-calling API for us, so tools are offered through a JSON output schema:
/// the model returns {"reply": "...", "tool_calls": [{"name": "...", "arguments_json": "{...}"}]}.
public struct CodexClient: LLMClient {
    public var executable: URL
    public var model: String
    public var timeout: TimeInterval = 240

    public init(executable: URL, model: String) { self.executable = executable; self.model = model }

    public static let suggestedModels = ["(Codex default)", "gpt-5.6-sol", "gpt-5.5", "gpt-5", "gpt-5-mini"]

    /// Finds `codex`: an explicit path, else common install locations (apps launched from Finder get a minimal PATH).
    public static func locate(_ explicit: String = "") -> URL? {
        let fm = FileManager.default
        let trimmed = explicit.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            let p = (trimmed as NSString).expandingTildeInPath
            return fm.isExecutableFile(atPath: p) ? URL(fileURLWithPath: p) : nil
        }
        let home = fm.homeDirectoryForCurrentUser.path
        let candidates = ["\(home)/.bun/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex", "\(home)/.npm-global/bin/codex",
                          "\(home)/.local/bin/codex", "\(home)/.volta/bin/codex", "\(home)/.cargo/bin/codex"]
        if let hit = candidates.first(where: { fm.isExecutableFile(atPath: $0) }) { return URL(fileURLWithPath: hit) }
        // nvm installs: ~/.nvm/versions/node/<v>/bin/codex
        let nvm = "\(home)/.nvm/versions/node"
        if let versions = try? fm.contentsOfDirectory(atPath: nvm) {
            for v in versions.sorted(by: >) where fm.isExecutableFile(atPath: "\(nvm)/\(v)/bin/codex") {
                return URL(fileURLWithPath: "\(nvm)/\(v)/bin/codex")
            }
        }
        return nil
    }

    static let schema: JSONValue = [
        "type": "object", "additionalProperties": false,
        "required": ["reply", "tool_calls"],
        "properties": [
            "reply": ["type": "string"],
            "tool_calls": ["type": "array", "items": [
                "type": "object", "additionalProperties": false, "required": ["name", "arguments_json"],
                "properties": ["name": ["type": "string"], "arguments_json": ["type": "string"]],
            ]],
        ],
    ]

    /// Flattens the conversation into one prompt (Codex runs are stateless here).
    public static func buildPrompt(system: String, messages: [ChatMessage], tools: [ToolSpec]) -> String {
        var out = "You are answering inside the Pinpoint screenshot app. Do not run shell commands or edit files; just answer.\n\n"
        if !system.isEmpty { out += "## Instructions\n\(system)\n\n" }
        if !tools.isEmpty {
            out += "## Tools\nYou act by returning tool calls in the JSON output: tool_calls is a list of {name, arguments_json} where arguments_json is a JSON object encoded as a string. Call every tool you need in ONE response when possible. When you are finished, return an empty tool_calls list and put a short summary in reply.\n"
            for t in tools { out += "- \(t.name): \(t.description)\n  parameters: \(t.parameters.jsonString)\n" }
            out += "\n"
        }
        out += "## Conversation\n"
        var imageNo = 0
        for m in messages {
            for p in m.parts {
                switch p {
                case .text(let t): out += "\(m.role == .user ? "USER" : "ASSISTANT"): \(t)\n"
                case .image: imageNo += 1; out += "\(m.role == .user ? "USER" : "ASSISTANT"): [attached image \(imageNo)]\n"
                case .toolUse(_, let name, let input): out += "ASSISTANT called \(name) \(input.jsonString)\n"
                case .toolResult(_, let content, let isError): out += "TOOL \(isError ? "ERROR" : "RESULT"): \(content)\n"
                }
            }
        }
        return out
    }

    /// Turns Codex's final message into a ChatResponse.
    public static func parse(_ text: String, expectTools: Bool) -> ChatResponse {
        guard expectTools else { return ChatResponse(parts: [.text(text.trimmingCharacters(in: .whitespacesAndNewlines))], stopReason: "end_turn") }
        guard let j = (try? JSONValue.parse(text)) ?? extractJSONObject(from: text) else {
            return ChatResponse(parts: [.text(text)], stopReason: "end_turn")
        }
        var parts: [ChatPart] = []
        if let r = j["reply"]?.stringValue, !r.isEmpty { parts.append(.text(r)) }
        for (i, c) in (j["tool_calls"]?.arrayValue ?? []).enumerated() {
            guard let name = c["name"]?.stringValue, !name.isEmpty else { continue }
            let args = c["arguments_json"]?.stringValue.flatMap { try? JSONValue.parse($0) } ?? c["arguments"] ?? [:]
            parts.append(.toolUse(id: "codex-\(i)-\(UUID().uuidString.prefix(6))", name: name, input: args))
        }
        return ChatResponse(parts: parts, stopReason: parts.contains { if case .toolUse = $0 { return true }; return false } ? "tool_use" : "end_turn")
    }

    public func send(system: String, messages: [ChatMessage], tools: [ToolSpec], maxTokens: Int) async throws -> ChatResponse {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("zoomies-codex-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        var args = ["exec", "--skip-git-repo-check", "--ephemeral", "-s", "read-only", "-C", dir.path,
                    "-c", "model_reasoning_effort=low", "-o", dir.appendingPathComponent("out.txt").path]
        if !model.isEmpty && !model.hasPrefix("(") { args += ["-m", model] }
        var n = 0
        for m in messages { for p in m.parts { if case .image(let png) = p {
            n += 1
            let url = dir.appendingPathComponent("image-\(n).png")
            try png.write(to: url)
            args += ["-i", url.path]
        } } }
        if !tools.isEmpty {
            let schemaURL = dir.appendingPathComponent("schema.json")
            try Self.schema.data().write(to: schemaURL)
            args += ["--output-schema", schemaURL.path]
        }
        args.append("-")   // prompt from stdin
        let prompt = Self.buildPrompt(system: system, messages: messages, tools: tools)
        let (status, stderr) = try await run(args: args, stdin: prompt, cwd: dir)
        let out = (try? String(contentsOf: dir.appendingPathComponent("out.txt"), encoding: .utf8)) ?? ""
        guard status == 0, !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let tail = stderr.split(separator: "\n").suffix(6).joined(separator: "\n")
            if tail.localizedCaseInsensitiveContains("login") || tail.localizedCaseInsensitiveContains("auth") {
                throw LLMError("Codex isn't signed in. Open Terminal, run `codex login` and choose “Sign in with ChatGPT”.\n\(tail)")
            }
            throw LLMError("Codex failed (exit \(status)): \(tail.isEmpty ? "no output" : tail)")
        }
        return Self.parse(out, expectTools: !tools.isEmpty)
    }

    private func run(args: [String], stdin: String, cwd: URL) async throws -> (Int32, String) {
        let exe = executable
        let limit = timeout
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = exe
                p.arguments = args
                p.currentDirectoryURL = cwd
                var env = ProcessInfo.processInfo.environment
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                // codex is often a Node/Bun script: make sure its interpreter is reachable from a Finder-launched app.
                env["PATH"] = [exe.deletingLastPathComponent().path, "\(home)/.bun/bin", "/opt/homebrew/bin", "/usr/local/bin",
                               "/usr/bin", "/bin", env["PATH"] ?? ""].joined(separator: ":")
                p.environment = env
                let inPipe = Pipe(), errPipe = Pipe()
                p.standardInput = inPipe
                p.standardOutput = FileHandle.nullDevice
                p.standardError = errPipe
                var errData = Data()
                let errLock = NSLock()
                errPipe.fileHandleForReading.readabilityHandler = { h in
                    let d = h.availableData
                    errLock.lock(); if errData.count < 200_000 { errData.append(d) }; errLock.unlock()
                }
                do { try p.run() } catch { cont.resume(throwing: LLMError("Couldn't start Codex: \(error.localizedDescription)")); return }
                inPipe.fileHandleForWriting.write(Data(stdin.utf8))
                try? inPipe.fileHandleForWriting.close()
                let deadline = DispatchTime.now() + limit
                DispatchQueue.global().asyncAfter(deadline: deadline) { if p.isRunning { p.terminate() } }
                p.waitUntilExit()
                errPipe.fileHandleForReading.readabilityHandler = nil
                errLock.lock(); let err = String(decoding: errData, as: UTF8.self); errLock.unlock()
                cont.resume(returning: (p.terminationStatus, err))
            }
        }
    }
}
