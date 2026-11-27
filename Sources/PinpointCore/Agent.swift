import CoreGraphics
import Foundation

/// The editable state the agent works on. Applied to the editor as one undoable step when the run ends.
public struct AgentState: Equatable, Sendable {
    public var annotations: [Annotation]
    public var crop: CGRect?
    public var name: String
    public var tags: [String]
    public var imageSize: CGSize
    public init(annotations: [Annotation], crop: CGRect?, name: String, tags: [String], imageSize: CGSize) {
        self.annotations = annotations; self.crop = crop; self.name = name; self.tags = tags; self.imageSize = imageSize
    }
}

/// Executes agent tool calls against AgentState. Pure (no network), so it is unit-tested directly.
/// `scale` maps original pixels to the pixels of the image the model saw (model = original * scale).
public struct AgentToolbox {
    public var state: AgentState
    public var analysis: Analysis
    public var scale: CGFloat
    public var color: RGBA

    public init(state: AgentState, analysis: Analysis, scale: CGFloat = 1, color: RGBA = .red) {
        self.state = state; self.analysis = analysis; self.scale = scale; self.color = color
    }

    var lineWidth: Double { Annotation.defaultLineWidth(for: state.imageSize) }
    var fontSize: Double { Annotation.defaultFontSize(for: state.imageSize) }
    var bounds: CGRect { CGRect(origin: .zero, size: state.imageSize) }

    func toImage(_ v: Double) -> CGFloat { CGFloat(v) / scale }
    func toModel(_ v: CGFloat) -> Int { Int((v * scale).rounded()) }
    func modelRect(_ r: CGRect) -> String { "x=\(toModel(r.minX)) y=\(toModel(r.minY)) w=\(toModel(r.width)) h=\(toModel(r.height))" }

    func clamp(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 0), state.imageSize.width), y: min(max(p.y, 0), state.imageSize.height))
    }

    var nextStep: Int {
        (state.annotations.filter { $0.kind == .step }.compactMap { Int($0.text ?? "") }.max() ?? 0) + 1
    }

    public static let tools: [ToolSpec] = [
        ToolSpec(name: "add_annotation",
                 description: "Add one markup item. Coordinates are pixels in the screenshot you were shown (origin top-left). Arrow: tail (x1,y1) to head (x2,y2). Box kinds (rectangle, ellipse, callout, highlight, blur, redact): opposite corners. Callout: speech bubble with text inside, its tail points down from the bottom-left. Text: top-left at (x1,y1). Step: numbered badge centred at (x1,y1); number is automatic unless text is given. Note: a numbered comment pin at (x1,y1) whose explanation goes in text (for handoffs).",
                 parameters: ["type": "object", "properties": [
                    "kind": ["type": "string", "enum": ["arrow", "line", "rectangle", "ellipse", "text", "callout", "highlight", "blur", "redact", "step", "note"]],
                    "x1": ["type": "number"], "y1": ["type": "number"], "x2": ["type": "number"], "y2": ["type": "number"],
                    "text": ["type": "string", "description": "Label for text, or number for step"],
                    "color": ["type": "string", "description": "red, orange, yellow, green, blue, purple, black, white or #rrggbb"],
                 ], "required": ["kind", "x1", "y1"]]),
        ToolSpec(name: "mark_text",
                 description: "Find on-screen text (from OCR) and mark every match. Best way to target buttons, labels and fields precisely. style: arrow points at it (optional label near the arrow tail), rectangle/ellipse outline it, highlight, blur or redact cover it, step puts a numbered badge beside it.",
                 parameters: ["type": "object", "properties": [
                    "query": ["type": "string", "description": "Text to find, e.g. 'Save'"],
                    "style": ["type": "string", "enum": ["arrow", "rectangle", "ellipse", "highlight", "blur", "redact", "step"]],
                    "label": ["type": "string"], "color": ["type": "string"],
                    "first_only": ["type": "boolean", "description": "Only mark the first match"],
                 ], "required": ["query", "style"]]),
        ToolSpec(name: "redact_sensitive",
                 description: "Cover sensitive info detected on-device (emails, API keys/secrets, phone numbers, card numbers, IP addresses, SSNs, faces).",
                 parameters: ["type": "object", "properties": [
                    "style": ["type": "string", "enum": ["blur", "redact"]],
                    "kinds": ["type": "array", "items": ["type": "string", "enum": .array(SensitiveKind.allCases.map { .string($0.rawValue) })],
                              "description": "Limit to these kinds; omit for all"],
                 ], "required": ["style"]]),
        ToolSpec(name: "list_annotations", description: "List current markup with ids and positions.",
                 parameters: ["type": "object", "properties": [:]]),
        ToolSpec(name: "remove_annotations", description: "Remove markup by id, or everything with all=true.",
                 parameters: ["type": "object", "properties": [
                    "ids": ["type": "array", "items": ["type": "string"]], "all": ["type": "boolean"]]]),
        ToolSpec(name: "crop", description: "Crop to a rectangle (pixels in the screenshot you saw). Use reset=true to remove the crop.",
                 parameters: ["type": "object", "properties": [
                    "x": ["type": "number"], "y": ["type": "number"], "width": ["type": "number"], "height": ["type": "number"],
                    "reset": ["type": "boolean"]]]),
        ToolSpec(name: "set_name_and_tags", description: "Rename the capture and set its search tags.",
                 parameters: ["type": "object", "properties": [
                    "name": ["type": "string"], "tags": ["type": "array", "items": ["type": "string"]]], "required": ["name"]]),
    ]

    @discardableResult
    public mutating func execute(_ name: String, _ input: JSONValue) -> (String, Bool) {
        switch name {
        case "add_annotation": return addAnnotation(input)
        case "mark_text": return markText(input)
        case "redact_sensitive": return redactSensitive(input)
        case "list_annotations": return (describeAnnotations(), false)
        case "remove_annotations":
            if input["all"]?.boolValue == true { let n = state.annotations.count; state.annotations.removeAll(); return ("Removed \(n) items.", false) }
            let ids = Set((input["ids"]?.arrayValue ?? []).compactMap { $0.stringValue?.lowercased() })
            let before = state.annotations.count
            state.annotations.removeAll { ids.contains(String($0.id.uuidString.prefix(6)).lowercased()) || ids.contains($0.id.uuidString.lowercased()) }
            return ("Removed \(before - state.annotations.count) items.", false)
        case "crop":
            if input["reset"]?.boolValue == true { state.crop = nil; return ("Crop removed.", false) }
            guard let x = input["x"]?.doubleValue, let y = input["y"]?.doubleValue,
                  let w = input["width"]?.doubleValue, let h = input["height"]?.doubleValue, w > 0, h > 0 else {
                return ("crop needs x, y, width, height", true)
            }
            let r = CGRect(x: toImage(x), y: toImage(y), width: toImage(w), height: toImage(h)).intersection(bounds)
            guard !r.isNull, r.width >= 4, r.height >= 4 else { return ("Crop is outside the image.", true) }
            state.crop = r.integral
            return ("Cropped to \(modelRect(r)).", false)
        case "set_name_and_tags":
            if let n = input["name"]?.stringValue, !n.isEmpty { state.name = String(n.prefix(80)) }
            if let t = input["tags"]?.arrayValue { state.tags = t.compactMap { $0.stringValue?.lowercased() }.filter { !$0.isEmpty } }
            return ("Name: \(state.name). Tags: \(state.tags.joined(separator: ", ")).", false)
        default:
            return ("Unknown tool \(name)", true)
        }
    }

    func shortID(_ id: UUID) -> String { String(id.uuidString.prefix(6)).lowercased() }

    public func describeAnnotations() -> String {
        if state.annotations.isEmpty { return "No markup yet." }
        return state.annotations.map { a in
            var s = "\(shortID(a.id)) \(a.kind.rawValue) \(modelRect(a.kind == .step || a.kind == .text ? a.bounds : a.rect))"
            if let t = a.text, !t.isEmpty { s += " \"\(t)\"" }
            return s
        }.joined(separator: "\n")
    }

    mutating func addAnnotation(_ input: JSONValue) -> (String, Bool) {
        guard let kindStr = input["kind"]?.stringValue, let kind = AnnotationKind(rawValue: kindStr) else { return ("Invalid kind", true) }
        guard let x1 = input["x1"]?.doubleValue, let y1 = input["y1"]?.doubleValue else { return ("x1 and y1 are required", true) }
        let p1 = clamp(CGPoint(x: toImage(x1), y: toImage(y1)))
        var p2 = p1
        if let x2 = input["x2"]?.doubleValue, let y2 = input["y2"]?.doubleValue { p2 = clamp(CGPoint(x: toImage(x2), y: toImage(y2))) }
        else if [.arrow, .line].contains(kind) || kind.isBox { return ("\(kind.rawValue) needs x2 and y2", true) }
        let c = RGBA.parse(input["color"]?.stringValue) ?? (kind == .redact ? .black : color)
        var text = input["text"]?.stringValue
        if kind == .step && (text ?? "").isEmpty { text = String(nextStep) }
        if (kind == .text || kind == .callout) && (text ?? "").isEmpty { return ("\(kind.rawValue) needs text", true) }
        if kind == .note && (text ?? "").isEmpty { return ("note needs text", true) }
        var a = Annotation(kind: kind, start: p1, end: p2, color: c, lineWidth: lineWidth, text: text, fontSize: fontSize)
        if kind == .note { a.note = text; a.text = nil }
        state.annotations.append(a)
        return ("Added \(kind.rawValue) \(shortID(a.id)).", false)
    }

    mutating func markText(_ input: JSONValue) -> (String, Bool) {
        guard let q = input["query"]?.stringValue, let style = input["style"]?.stringValue else { return ("query and style required", true) }
        var matches = Analyzer.find(q, in: analysis.lines)
        if matches.isEmpty {
            let sample = analysis.lines.prefix(40).map(\.text).joined(separator: " | ")
            return ("No on-screen text matches \"\(q)\". Visible text includes: \(sample). Use add_annotation with coordinates instead.", true)
        }
        if input["first_only"]?.boolValue == true { matches = [matches[0]] }
        let c = RGBA.parse(input["color"]?.stringValue) ?? color
        let pad = max(4, CGFloat(lineWidth) * 1.5)
        var added = 0
        for m in matches {
            let r = m.rect.insetBy(dx: -pad, dy: -pad).intersection(bounds)
            switch style {
            case "arrow":
                let len = max(80, min(state.imageSize.width, state.imageSize.height) * 0.12)
                // Come in from whichever side has room, aiming at the near edge.
                let fromLeft = r.minX > len + 10
                let fromTop = r.minY > len * 0.6 + 10
                let head = CGPoint(x: fromLeft ? r.minX - 4 : r.maxX + 4, y: fromTop ? r.minY - 2 : r.maxY + 2)
                let tail = clamp(CGPoint(x: head.x + (fromLeft ? -len : len), y: head.y + (fromTop ? -len * 0.6 : len * 0.6)))
                state.annotations.append(Annotation(kind: .arrow, start: tail, end: head, color: c, lineWidth: lineWidth, fontSize: fontSize))
                if let label = input["label"]?.stringValue, !label.isEmpty {
                    var t = Annotation(kind: .text, start: .zero, end: .zero, color: c, lineWidth: lineWidth, text: label, fontSize: fontSize)
                    let s = t.textSize
                    let x = fromLeft ? tail.x - s.width - 6 : tail.x + 6
                    let y = fromTop ? tail.y - s.height - 2 : tail.y + 2
                    t.start = clamp(CGPoint(x: max(0, x), y: max(0, y)))
                    t.end = t.start
                    state.annotations.append(t)
                }
            case "step":
                let rad = CGFloat(fontSize) * 0.8
                let centre = clamp(CGPoint(x: r.minX - rad - 4 >= 0 ? r.minX - rad - 4 : r.maxX + rad + 4, y: r.midY))
                state.annotations.append(Annotation(kind: .step, start: centre, end: centre, color: c, lineWidth: lineWidth,
                                                    text: input["label"]?.stringValue ?? String(nextStep), fontSize: fontSize))
            case "rectangle", "ellipse", "highlight", "blur", "redact":
                let kind = AnnotationKind(rawValue: style)!
                let box = style == "ellipse" ? r.insetBy(dx: -r.width * 0.1, dy: -r.height * 0.25).intersection(bounds) : r
                state.annotations.append(Annotation(kind: kind, start: box.origin, end: CGPoint(x: box.maxX, y: box.maxY),
                                                    color: kind == .redact ? .black : (kind == .highlight && input["color"] == nil ? .yellow : c),
                                                    lineWidth: lineWidth, fontSize: fontSize))
            default:
                return ("Unknown style \(style)", true)
            }
            added += 1
        }
        return ("Marked \(added) match(es) for \"\(q)\": " + matches.map { "\"\($0.text)\" at \(modelRect($0.rect))" }.joined(separator: "; "), false)
    }

    mutating func redactSensitive(_ input: JSONValue) -> (String, Bool) {
        let style: AnnotationKind = input["style"]?.stringValue == "redact" ? .redact : .blur
        let kinds = input["kinds"]?.arrayValue.map { Set($0.compactMap { $0.stringValue.flatMap(SensitiveKind.init(rawValue:)) }) }
        let regions = analysis.sensitive.filter { kinds?.contains($0.kind) ?? true }
        if regions.isEmpty { return ("Nothing sensitive was detected on-device. If you can see something, cover it with add_annotation (blur/redact).", false) }
        state.annotations.append(contentsOf: Analyzer.redactions(for: regions, style: style, imageSize: state.imageSize))
        let counts = Dictionary(grouping: regions, by: \.kind).map { "\($0.value.count) \($0.key.label)" }.sorted()
        return ("Covered " + counts.joined(separator: ", ") + ".", false)
    }
}

/// Tool-using agent loop: shows the model the screenshot + OCR, lets it call tools, returns the edited state.
public final class EditAgent: @unchecked Sendable {
    public let client: LLMClient
    public var maxSteps: Int

    public init(client: LLMClient, maxSteps: Int = 12) { self.client = client; self.maxSteps = maxSteps }

    public func run(instruction: String, image: CGImage, analysis: Analysis, state: AgentState, color: RGBA = .red,
                    onEvent: @escaping @Sendable (String) -> Void = { _ in }) async throws -> (state: AgentState, reply: String) {
        let sent = ImageFiles.forModel(image)
        var box = AgentToolbox(state: state, analysis: analysis, scale: sent.scale, color: color)
        let ocr = analysis.lines.prefix(250).map { "- \"\($0.text)\" at \(box.modelRect($0.rect))" }.joined(separator: "\n")
        let sens = analysis.sensitive.isEmpty ? "none" :
            Dictionary(grouping: analysis.sensitive, by: \.kind).map { "\($0.value.count) \($0.key.label)" }.sorted().joined(separator: ", ")
        let system = """
        You are the editing agent inside Pinpoint, a macOS screenshot tool. You edit the user's screenshot only by calling tools.
        The screenshot is \(Int(sent.size.width))x\(Int(sent.size.height)) pixels; all coordinates are in that space, origin top-left.
        Prefer mark_text to target visible text (buttons, menu items, fields) because it uses exact OCR boxes.
        For privacy requests use redact_sensitive first, then add_annotation for anything it missed.
        Keep markup clean and minimal. When finished, reply with one or two short sentences saying what you did, without calling tools.
        """
        let context = """
        Text found on screen (OCR):
        \(ocr.isEmpty ? "(none)" : ocr)

        Sensitive items detected on-device: \(sens)
        Current markup:
        \(box.describeAnnotations())
        Capture name: \(state.name)

        Request: \(instruction)
        """
        var messages: [ChatMessage] = [ChatMessage(role: .user, parts: [.image(png: sent.data), .text(context)])]
        for _ in 0..<maxSteps {
            try Task.checkCancellation()
            let resp = try await client.send(system: system, messages: messages, tools: AgentToolbox.tools, maxTokens: 2048)
            messages.append(ChatMessage(role: .assistant, parts: resp.parts))
            let calls = resp.toolCalls
            if calls.isEmpty { return (box.state, resp.text.isEmpty ? "Done." : resp.text) }
            var results: [ChatPart] = []
            for call in calls {
                let (out, isError) = box.execute(call.name, call.input)
                onEvent("\(call.name): \(out)")
                results.append(.toolResult(id: call.id, content: out, isError: isError))
            }
            messages.append(ChatMessage(role: .user, parts: results))
        }
        return (box.state, "Stopped after \(maxSteps) steps.")
    }
}
