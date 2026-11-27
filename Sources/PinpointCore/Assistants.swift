import CoreGraphics
import Foundation
import Security

/// One-shot AI helpers built on any LLMClient.
public struct Assistants: Sendable {
    public let client: LLMClient
    public init(client: LLMClient) { self.client = client }

    public func summarize(image: CGImage, ocrText: String) async throws -> String {
        let img = ImageFiles.forModel(image, maxDimension: 1280).data
        return try await client.ask(
            system: "You summarise screenshots. Be concise and factual.",
            prompt: "Summarise what this screenshot shows in 2-4 sentences, then list any key facts, numbers or action items as short bullets.\n\nOCR text:\n\(ocrText.prefix(6000))",
            images: [img], maxTokens: 800)
    }

    public func nameAndTags(image: CGImage, ocrText: String, app: String?) async throws -> (name: String, tags: [String]) {
        let img = ImageFiles.forModel(image, maxDimension: 1024).data
        let text = try await client.ask(
            system: "You label screenshots for a searchable library. Reply with JSON only.",
            prompt: """
            Give this screenshot a short descriptive file name (3-7 words, no extension, no dates) and 3-6 lowercase search tags.
            Never put secrets, emails or personal data in the name or tags.
            App: \(app ?? "unknown")
            OCR text: \(ocrText.prefix(2000))
            Reply exactly as {"name": "...", "tags": ["...", "..."]}
            """,
            images: [img], maxTokens: 200)
        guard let j = extractJSONObject(from: text), let name = j["name"]?.stringValue, !name.isEmpty else {
            throw LLMError("The model didn't return a name")
        }
        let tags = (j["tags"]?.arrayValue ?? []).compactMap { $0.stringValue?.lowercased().trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return (String(name.prefix(80)), Array(tags.prefix(8)))
    }

    /// Writes a step-by-step guide. The model places {{image N}} where screenshot N belongs.
    public func writeGuide(steps: [GuideStep], title: String?) async throws -> String {
        let imgs = steps.map { ImageFiles.forModel($0.image, maxDimension: 1024).data }
        let listing = steps.enumerated().map { i, s in "Screenshot \(i + 1): \(s.name)\nOCR: \(s.ocrText.prefix(800))" }.joined(separator: "\n\n")
        return try await client.ask(
            system: "You write clear, friendly step-by-step how-to guides from ordered screenshots. Output Markdown only.",
            prompt: """
            Write a how-to guide from these \(steps.count) screenshots, in order\(title.map { ", titled \"\($0)\"" } ?? "").
            Start with a "# " title and one sentence of intro. Then one "## Step N: ..." section per screenshot with 1-3 sentences of
            instructions in the imperative, mentioning exact button and menu names you can see. Put the line {{image N}} on its own
            line in step N where screenshot N belongs. End with a short "## Tips" section only if genuinely useful.

            \(listing)
            """,
            images: imgs, maxTokens: 3000)
    }
}

// MARK: - Guides

public struct GuideStep: Sendable {
    public var image: CGImage
    public var name: String
    public var ocrText: String
    public init(image: CGImage, name: String, ocrText: String) { self.image = image; self.name = name; self.ocrText = ocrText }
}

public enum GuideBuilder {
    /// Offline guide: one section per screenshot.
    public static func fallbackMarkdown(steps: [GuideStep], title: String) -> String {
        var md = "# \(title)\n\n"
        for (i, s) in steps.enumerated() { md += "## Step \(i + 1): \(s.name)\n\n{{image \(i + 1)}}\n\n" }
        return md
    }

    /// Writes guide.md, guide.html and images/ into a new folder under `parent`. Returns the folder.
    public static func write(markdown: String, steps: [GuideStep], title: String, to parent: URL) throws -> URL {
        let fm = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: Date()).prefix(19).replacingOccurrences(of: ":", with: "-")
        let safe = title.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>")).joined(separator: "-")
        let folder = parent.appendingPathComponent("\(safe.prefix(60)) \(stamp)", isDirectory: true)
        try fm.createDirectory(at: folder.appendingPathComponent("images"), withIntermediateDirectories: true)
        for (i, s) in steps.enumerated() {
            try ImageFiles.write(s.image, to: folder.appendingPathComponent("images/step-\(i + 1).png"))
        }
        var md = markdown
        var used = Set<Int>()
        for i in 1...max(1, steps.count) where i <= steps.count {
            let token = "{{image \(i)}}"
            if md.contains(token) { used.insert(i) }
            md = md.replacingOccurrences(of: token, with: "![Step \(i)](images/step-\(i).png)")
        }
        // Append any screenshot the model forgot to place.
        for i in 1...max(1, steps.count) where i <= steps.count && !used.contains(i) {
            md += "\n\n![Step \(i)](images/step-\(i).png)\n"
        }
        try md.write(to: folder.appendingPathComponent("guide.md"), atomically: true, encoding: .utf8)
        let html = """
        <!doctype html><html><head><meta charset="utf-8"><title>\(Markdown.escape(title))</title>
        <style>body{font:16px/1.6 -apple-system,system-ui,sans-serif;max-width:860px;margin:40px auto;padding:0 20px;color:#1d1d1f}
        img{max-width:100%;border-radius:10px;box-shadow:0 4px 18px rgba(0,0,0,.15);margin:8px 0 20px}
        h1{font-size:2em}h2{margin-top:1.8em}code{background:#f2f2f5;padding:2px 5px;border-radius:4px}</style></head>
        <body>\(Markdown.toHTML(md))</body></html>
        """
        try html.write(to: folder.appendingPathComponent("guide.html"), atomically: true, encoding: .utf8)
        return folder
    }
}

/// Tiny Markdown -> HTML converter covering what guides use: headings, paragraphs, lists, images, bold, italics, code.
public enum Markdown {
    public static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func inline(_ s: String) -> String {
        var t = escape(s)
        // Guide text comes from the model, so links may only be relative, http(s) or mailto (no javascript: etc.).
        let url = #"((?:https?://|mailto:|(?![\w+.-]+:))[^)\s]+)"#
        let rules: [(String, String)] = [
            (#"!\[([^\]]*)\]\("# + url + #"\)"#, "<img alt=\"$1\" src=\"$2\">"),
            (#"\[([^\]]+)\]\("# + url + #"\)"#, "<a href=\"$2\">$1</a>"),
            (#"\*\*([^*]+)\*\*"#, "<strong>$1</strong>"),
            (#"(?<![*\w])\*([^*]+)\*(?![*\w])"#, "<em>$1</em>"),
            (#"`([^`]+)`"#, "<code>$1</code>"),
        ]
        for (p, r) in rules { t = t.replacingOccurrences(of: p, with: r, options: .regularExpression) }
        return t
    }

    public static func toHTML(_ md: String) -> String {
        var out: [String] = []
        var para: [String] = []
        var list: String? = nil
        func flushPara() { if !para.isEmpty { out.append("<p>" + inline(para.joined(separator: " ")) + "</p>"); para = [] } }
        func closeList() { if let l = list { out.append("</\(l)>"); list = nil } }
        for raw in md.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flushPara(); closeList(); continue }
            if let m = line.range(of: #"^#{1,6} "#, options: .regularExpression) {
                flushPara(); closeList()
                let level = line[m].filter { $0 == "#" }.count
                out.append("<h\(level)>" + inline(String(line[m.upperBound...])) + "</h\(level)>")
            } else if let m = line.range(of: #"^[-*] "#, options: .regularExpression) {
                flushPara(); if list != "ul" { closeList(); out.append("<ul>"); list = "ul" }
                out.append("<li>" + inline(String(line[m.upperBound...])) + "</li>")
            } else if let m = line.range(of: #"^\d+[.)] "#, options: .regularExpression) {
                flushPara(); if list != "ol" { closeList(); out.append("<ol>"); list = "ol" }
                out.append("<li>" + inline(String(line[m.upperBound...])) + "</li>")
            } else {
                closeList(); para.append(line)
            }
        }
        flushPara(); closeList()
        return out.joined(separator: "\n")
    }
}

// MARK: - Keychain

public enum Keychain {
    public static let service = "app.pinpoint.apikeys"

    public static func get(_ account: String, service: String = Keychain.service) -> String {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return "" }
        return String(decoding: d, as: UTF8.self)
    }

    @discardableResult
    public static func set(_ value: String, for account: String, service: String = Keychain.service) -> Bool {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(base as CFDictionary)
        guard !value.isEmpty else { return true }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
}
