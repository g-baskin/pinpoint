import AppKit
import CoreGraphics
import XCTest
@testable import PinpointCore

final class SensitiveTests: XCTestCase {
    func testFindsCommonSecretsAndPII() {
        // Split so GitHub push protection does not flag this fake key.
        let fakeAWSKey = "AKIA" + "ABCDEFGHIJKLMNOP"
        let text = "Contact jane.doe@example.com or +1 (555) 123-4567. Key \(fakeAWSKey), token sk-proj-abcdefghijklmnop1234 card 4242 4242 4242 4242 ip 192.168.1.20"
        let kinds = Set(SensitiveDetector.findMatches(in: text).map(\.kind))
        XCTAssertEqual(kinds, [.email, .phone, .apiKey, .creditCard, .ipAddress])
    }

    func testRejectsNonLuhnNumbers() {
        XCTAssertTrue(SensitiveDetector.findMatches(in: "order 1234 5678 9012 3456").allSatisfy { $0.kind != .creditCard })
    }

    func testPlainTextHasNoMatches() {
        XCTAssertTrue(SensitiveDetector.findMatches(in: "Click Save to keep your changes").isEmpty)
    }
}

final class JSONTests: XCTestCase {
    func testRoundTripAndAccessors() throws {
        let v: JSONValue = ["a": 1, "b": ["x", true], "c": nil]
        let back = try JSONValue.parse(v.data())
        XCTAssertEqual(back, v)
        XCTAssertEqual(back["a"]?.doubleValue, 1)
        XCTAssertEqual(back["b"]?[0]?.stringValue, "x")
    }

    func testExtractJSONFromProse() {
        let j = extractJSONObject(from: "Sure! ```json\n{\"name\": \"Login {page}\", \"tags\": [\"auth\"]}\n``` done")
        XCTAssertEqual(j?["name"]?.stringValue, "Login {page}")
    }
}

func makeImage(width: Int = 800, height: Int = 600, text: [(String, CGPoint)] = []) -> CGImage {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(.white); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    for (s, p) in text {
        (s as NSString).draw(at: p, withAttributes: [.font: NSFont.systemFont(ofSize: 28), .foregroundColor: NSColor.black])
    }
    NSGraphicsContext.restoreGraphicsState()
    return ctx.makeImage()!
}

final class RenderTests: XCTestCase {
    func testFlattenDrawsRedactionAndCrops() throws {
        let base = makeImage()
        let red = Annotation(kind: .redact, start: CGPoint(x: 10, y: 10), end: CGPoint(x: 110, y: 60), color: .black)
        let out = try XCTUnwrap(Renderer.flatten(base: base, annotations: [red], crop: nil))
        XCTAssertEqual(out.width, 800)
        // Pixel inside the redaction (top-left origin) should be black.
        let rep = NSBitmapImageRep(cgImage: out)
        let c = try XCTUnwrap(rep.colorAt(x: 50, y: 30))
        XCTAssertLessThan(c.brightnessComponent, 0.1)
        let white = try XCTUnwrap(rep.colorAt(x: 400, y: 400))
        XCTAssertGreaterThan(white.brightnessComponent, 0.9)

        let cropped = try XCTUnwrap(Renderer.flatten(base: base, annotations: [], crop: CGRect(x: 0, y: 0, width: 200, height: 100)))
        XCTAssertEqual(cropped.width, 200); XCTAssertEqual(cropped.height, 100)
    }

    func testAllKindsRenderWithoutCrashing() throws {
        let base = makeImage()
        let items = AnnotationKind.allCases.map { Annotation(kind: $0, start: CGPoint(x: 100, y: 100), end: CGPoint(x: 300, y: 200), text: "Hi") }
        XCTAssertNotNil(Renderer.flatten(base: base, annotations: items, crop: nil))
    }

    func testHitTesting() {
        let a = Annotation(kind: .arrow, start: .zero, end: CGPoint(x: 100, y: 100), lineWidth: 4)
        XCTAssertTrue(a.hitTest(CGPoint(x: 50, y: 52), tolerance: 4))
        XCTAssertFalse(a.hitTest(CGPoint(x: 90, y: 10), tolerance: 4))
    }
}

final class AnalyzerTests: XCTestCase {
    func testOCRFindsTextAndEmailBox() throws {
        let img = makeImage(width: 1000, height: 400, text: [("Save Changes", CGPoint(x: 60, y: 60)), ("Email: test.user@example.com", CGPoint(x: 60, y: 220))])
        let a = try Analyzer.analyze(img, faces: false)
        XCTAssertTrue(a.fullText.contains("Save"), a.fullText)
        let save = try XCTUnwrap(Analyzer.find("save", in: a.lines).first)
        XCTAssertLessThan(save.rect.minY, 150, "top-left origin conversion")
        let email = try XCTUnwrap(a.sensitive.first { $0.kind == .email })
        XCTAssertGreaterThan(email.rect.minY, 180)
        XCTAssertGreaterThan(email.rect.minX, 100, "box should cover the address, not the 'Email:' label")
    }

    func testTallImageIsReadInStripsWithoutDuplicates() throws {
        // 600 wide → 1200 px strips overlapping 1000–1200; the middle line sits in that overlap.
        let img = makeImage(width: 600, height: 5000, text: [("First line here", CGPoint(x: 40, y: 80)),
                                                            ("Overlap line", CGPoint(x: 40, y: 1090)),
                                                            ("Mail bottom@example.com", CGPoint(x: 40, y: 4850))])
        let a = try Analyzer.analyze(img, faces: false)
        XCTAssertEqual(Analyzer.find("overlap line", in: a.lines).count, 1, a.fullText)
        XCTAssertLessThan(try XCTUnwrap(Analyzer.find("first line", in: a.lines).first).rect.minY, 200)
        let email = try XCTUnwrap(a.sensitive.first { $0.kind == .email }, a.fullText)
        XCTAssertGreaterThan(email.rect.minY, 4800)
        XCTAssertEqual(a.sensitive.filter { $0.kind == .email }.count, 1)
    }
}

final class LibraryTests: XCTestCase {
    func testCreateSaveLoadSearch() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pinpoint-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = LibraryStore(root: dir)
        var m = try store.create(image: makeImage(), name: "First", sourceApp: "Safari")
        m.tags = ["billing"]; m.ocrText = "Invoice total 42"
        m.annotations = [Annotation(kind: .step, start: CGPoint(x: 20, y: 20), end: CGPoint(x: 20, y: 20), text: "1")]
        try store.save(m, rendered: makeImage())
        _ = try store.create(image: makeImage(), name: "Second")
        let all = store.loadAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(store.meta(m.id)?.annotations.count, 1)
        XCTAssertEqual(LibraryStore.search(all, query: "invoice safari").map(\.name), ["First"])
        XCTAssertEqual(LibraryStore.search(all, query: "#billing").count, 1)
        XCTAssertNotNil(store.bestImage(m.id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.thumbURL(m.id).path))
    }
}

final class AgentToolboxTests: XCTestCase {
    let analysis = Analysis(
        lines: [OCRLine(text: "Save", rect: CGRect(x: 600, y: 500, width: 60, height: 24)),
                OCRLine(text: "Cancel", rect: CGRect(x: 500, y: 500, width: 70, height: 24))],
        sensitive: [SensitiveRegion(kind: .email, text: "a@b.co", rect: CGRect(x: 10, y: 10, width: 100, height: 20)),
                    SensitiveRegion(kind: .face, text: nil, rect: CGRect(x: 300, y: 100, width: 80, height: 80))])

    func box(scale: CGFloat = 1) -> AgentToolbox {
        AgentToolbox(state: AgentState(annotations: [], crop: nil, name: "x", tags: [], imageSize: CGSize(width: 1000, height: 800)),
                     analysis: analysis, scale: scale)
    }

    func testMarkTextArrowPointsAtButton() {
        var b = box()
        let (out, err) = b.execute("mark_text", ["query": "save", "style": "arrow", "label": "Click here"])
        XCTAssertFalse(err, out)
        let arrow = b.state.annotations.first { $0.kind == .arrow }!
        let target = CGRect(x: 600, y: 500, width: 60, height: 24).insetBy(dx: -20, dy: -20)
        XCTAssertTrue(target.contains(arrow.end), "arrow head \(arrow.end) should be at the Save button")
        XCTAssertTrue(b.state.annotations.contains { $0.kind == .text && $0.text == "Click here" })
    }

    func testScaleConvertsModelCoordinates() {
        var b = box(scale: 0.5)
        b.execute("add_annotation", ["kind": "rectangle", "x1": 50, "y1": 50, "x2": 100, "y2": 100])
        XCTAssertEqual(b.state.annotations[0].rect, CGRect(x: 100, y: 100, width: 100, height: 100))
        b.execute("crop", ["x": 0, "y": 0, "width": 250, "height": 200])
        XCTAssertEqual(b.state.crop, CGRect(x: 0, y: 0, width: 500, height: 400))
    }

    func testRedactSensitiveByKind() {
        var b = box()
        b.execute("redact_sensitive", ["style": "redact", "kinds": ["face"]])
        XCTAssertEqual(b.state.annotations.count, 1)
        XCTAssertEqual(b.state.annotations[0].kind, .redact)
        b.execute("redact_sensitive", ["style": "blur"])
        XCTAssertEqual(b.state.annotations.count, 3)
    }

    func testStepsNumberThemselvesAndRemove() {
        var b = box()
        b.execute("add_annotation", ["kind": "step", "x1": 10, "y1": 10])
        b.execute("mark_text", ["query": "cancel", "style": "step"])
        XCTAssertEqual(b.state.annotations.compactMap(\.text), ["1", "2"])
        b.execute("remove_annotations", ["all": true])
        XCTAssertTrue(b.state.annotations.isEmpty)
    }

    func testMissingTextReportsError() {
        var b = box()
        let (out, err) = b.execute("mark_text", ["query": "Publish", "style": "rectangle"])
        XCTAssertTrue(err); XCTAssertTrue(out.contains("No on-screen text"))
    }
}

/// Scripted model: proves the agent loop wires tool calls -> toolbox -> results -> final reply.
struct ScriptedClient: LLMClient {
    final class Box: @unchecked Sendable { var calls = 0; var lastMessages: [ChatMessage] = [] }
    let box = Box()
    func send(system: String, messages: [ChatMessage], tools: [ToolSpec], maxTokens: Int) async throws -> ChatResponse {
        box.calls += 1
        box.lastMessages = messages
        if box.calls == 1 {
            return ChatResponse(parts: [.toolUse(id: "t1", name: "mark_text", input: ["query": "Save", "style": "rectangle"]),
                                        .toolUse(id: "t2", name: "set_name_and_tags", input: ["name": "Save dialog", "tags": ["dialog"]])], stopReason: "tool_use")
        }
        return ChatResponse(parts: [.text("Outlined the Save button.")], stopReason: "end_turn")
    }
}

final class AgentLoopTests: XCTestCase {
    func testLoopAppliesToolsAndReturnsReply() async throws {
        let img = makeImage(width: 1000, height: 800)
        let client = ScriptedClient()
        let analysis = Analysis(lines: [OCRLine(text: "Save", rect: CGRect(x: 600, y: 500, width: 60, height: 24))], sensitive: [])
        let state = AgentState(annotations: [], crop: nil, name: "Capture", tags: [], imageSize: CGSize(width: 1000, height: 800))
        let r = try await EditAgent(client: client).run(instruction: "outline save", image: img, analysis: analysis, state: state)
        XCTAssertEqual(r.reply, "Outlined the Save button.")
        XCTAssertEqual(r.state.annotations.map(\.kind), [.rectangle])
        XCTAssertEqual(r.state.name, "Save dialog")
        XCTAssertEqual(client.box.calls, 2)
        // Second request must carry both tool results.
        let results = client.box.lastMessages.last!.parts.filter { if case .toolResult = $0 { return true }; return false }
        XCTAssertEqual(results.count, 2)
    }
}

final class ProviderWireTests: XCTestCase {
    let msgs: [ChatMessage] = [
        .user("hi", images: [Data([1, 2, 3])]),
        ChatMessage(role: .assistant, parts: [.text("ok"), .toolUse(id: "c1", name: "crop", input: ["x": 1])]),
        ChatMessage(role: .user, parts: [.toolResult(id: "c1", content: "done", isError: false)]),
    ]
    let tools = [ToolSpec(name: "crop", description: "d", parameters: ["type": "object"])]

    func testAnthropicRequestShape() throws {
        let c = AnthropicClient(apiKey: "k", model: "m", baseURL: URL(string: "https://api.anthropic.com")!)
        let req = c.makeRequest(system: "sys", messages: msgs, tools: tools, maxTokens: 100)
        XCTAssertEqual(req.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "k")
        let j = try JSONValue.parse(req.httpBody!)
        XCTAssertEqual(j["system"]?.stringValue, "sys")
        XCTAssertEqual(j["messages"]?[0]?["content"]?[0]?["type"]?.stringValue, "image")
        XCTAssertEqual(j["messages"]?[2]?["content"]?[0]?["tool_use_id"]?.stringValue, "c1")
        XCTAssertEqual(j["tools"]?[0]?["input_schema"]?["type"]?.stringValue, "object")
    }

    func testAnthropicParse() throws {
        let data = Data(#"{"content":[{"type":"text","text":"hey"},{"type":"tool_use","id":"x","name":"crop","input":{"x":2}}],"stop_reason":"tool_use"}"#.utf8)
        let r = try AnthropicClient.parse(data)
        XCTAssertEqual(r.text, "hey")
        XCTAssertEqual(r.toolCalls, [ToolCall(id: "x", name: "crop", input: ["x": 2])])
    }

    func testOpenAIRequestShape() throws {
        let c = OpenAICompatibleClient(apiKey: "k", model: "m", baseURL: URL(string: "https://api.openai.com/v1")!)
        let req = c.makeRequest(system: "sys", messages: msgs, tools: tools, maxTokens: 100)
        XCTAssertEqual(req.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(req.value(forHTTPHeaderField: "authorization"), "Bearer k")
        let j = try JSONValue.parse(req.httpBody!)
        let m = j["messages"]!.arrayValue!
        XCTAssertEqual(m.map { $0["role"]?.stringValue }, ["system", "user", "assistant", "tool"])
        XCTAssertTrue(m[1]["content"]?[0]?["image_url"]?["url"]?.stringValue?.hasPrefix("data:image/png;base64,") ?? false)
        XCTAssertEqual(m[2]["tool_calls"]?[0]?["function"]?["arguments"]?.stringValue, #"{"x":1}"#)
        XCTAssertEqual(m[3]["tool_call_id"]?.stringValue, "c1")
        XCTAssertEqual(j["tools"]?[0]?["function"]?["name"]?.stringValue, "crop")
    }

    func testOpenAIParse() throws {
        let data = Data(#"{"choices":[{"message":{"content":null,"tool_calls":[{"id":"q","type":"function","function":{"name":"crop","arguments":"{\"x\":3}"}}]},"finish_reason":"tool_calls"}]}"#.utf8)
        let r = try OpenAICompatibleClient.parse(data)
        XCTAssertEqual(r.toolCalls, [ToolCall(id: "q", name: "crop", input: ["x": 3])])
    }
}

final class GuideTests: XCTestCase {
    func testWritesGuideWithAllImages() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pinpoint-guide-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let steps = [GuideStep(image: makeImage(), name: "Open", ocrText: ""), GuideStep(image: makeImage(), name: "Save", ocrText: "")]
        let folder = try GuideBuilder.write(markdown: "# T\n\n## Step 1: **Open**\n\n{{image 1}}\n", steps: steps, title: "T", to: dir)
        let md = try String(contentsOf: folder.appendingPathComponent("guide.md"), encoding: .utf8)
        XCTAssertTrue(md.contains("images/step-1.png") && md.contains("images/step-2.png"), "forgotten image 2 appended")
        let html = try String(contentsOf: folder.appendingPathComponent("guide.html"), encoding: .utf8)
        XCTAssertTrue(html.contains("<h2>Step 1: <strong>Open</strong></h2>"))
        XCTAssertTrue(html.contains(#"<img alt="Step 2" src="images/step-2.png">"#))
    }
}

final class AccountIDTests: XCTestCase {
    func kinds(_ s: String, custom: [String] = []) -> [SensitiveKind] { SensitiveDetector.findMatches(in: s, customTerms: custom).map(\.kind) }

    func testMetaAdAccountFromUsersScreenshot() {
        let line = "act_637806241957561. It last synced successfully at 18:00 today. TapSonar uses this"
        let m = SensitiveDetector.findMatches(in: line)
        XCTAssertEqual(m.map(\.kind), [.accountID])
        XCTAssertEqual(m.first?.value, "act_637806241957561")
    }

    func testOtherPlatformIDs() {
        XCTAssertEqual(kinds("Pixel ID 1234567890123456 is live"), [.accountID])
        XCTAssertEqual(kinds("token EAAGm0PX4ZCpsBAKZB2zxyzLongTokenValue123"), [.apiKey])
        XCTAssertEqual(kinds("Stripe acct_1NAbcDEfGhIjKlMn"), [.accountID])
        XCTAssertEqual(kinds("GA: G-ABC123XYZ9 and GTM-5XK2P7"), [.accountID, .accountID])
        XCTAssertTrue(kinds("Customer ID: 123-456-7890").contains(.accountID))
    }

    func testShortNumbersAndCardsStillCorrect() {
        XCTAssertTrue(kinds("Order 12345 shipped at 18:00").isEmpty)
        XCTAssertEqual(kinds("card 4242424242424242"), [.creditCard], "a real (Luhn-valid) card number stays a card")
    }

    func testCustomTerms() {
        let m = SensitiveDetector.findMatches(in: "Meta Ads connection \"Storewren\" for StoreWren BlackFriday", customTerms: ["storewren"])
        XCTAssertEqual(m.filter { $0.kind == .custom }.count, 2)
    }
}
