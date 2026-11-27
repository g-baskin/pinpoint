import CryptoKit
import XCTest
@testable import PinpointCore

final class ChatGPTPlanTests: XCTestCase {
    func testPKCEChallengeIsSHA256OfVerifier() {
        let (v, c) = ChatGPTOAuth.pkce()
        XCTAssertEqual(c, ChatGPTOAuth.base64url(Data(SHA256.hash(data: Data(v.utf8)))))
        XCTAssertFalse(v.contains("=") || v.contains("+") || v.contains("/"))
        XCTAssertGreaterThanOrEqual(v.count, 43)
    }

    func testAuthorizeURLForFirstSignInRegistersPinpoint() throws {
        let url = ChatGPTOAuth.authorizeRequestURL(clientId: nil, hostId: "urn:uuid:x", email: nil,
                                                   redirectURI: "http://127.0.0.1:1455/auth/callback", state: "s", nonce: "n", challenge: "c")
        let q = Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(url.host, "auth.openai.com")
        XCTAssertEqual(q["client_id"], "dynamic_agent_client")
        XCTAssertEqual(q["agent_name_hint"], "Pinpoint")
        XCTAssertTrue(q["scope"]!.contains("chatgpt.tokens.use.direct"))
        XCTAssertEqual(q["resource"], "https://api.openai.com/v1")
        XCTAssertEqual(q["code_challenge_method"], "S256")
    }

    func testAuthorizeURLForReturningUserUsesIssuedClient() {
        let url = ChatGPTOAuth.authorizeRequestURL(clientId: "app_123", hostId: "h", email: "a@b.co",
                                                   redirectURI: "r", state: "s", nonce: "n", challenge: "c")
        let s = url.absoluteString
        XCTAssertTrue(s.contains("client_id=app_123"))
        XCTAssertFalse(s.contains("agent_name_hint"))
        XCTAssertTrue(s.contains("login_hint=a@b.co"))
    }

    func testJWTClaims() {
        let payload = ChatGPTOAuth.base64url(Data(#"{"sub":"user-1","email":"me@x.com","nonce":"abc"}"#.utf8))
        let claims = ChatGPTOAuth.jwtClaims("e30.\(payload).sig")
        XCTAssertEqual(claims?["sub"]?.stringValue, "user-1")
        XCTAssertEqual(claims?["nonce"]?.stringValue, "abc")
    }

    func testResponsesBodyShape() throws {
        let msgs: [ChatMessage] = [
            .user("hi", images: [Data([1, 2])]),
            ChatMessage(role: .assistant, parts: [.text("ok"), .toolUse(id: "call_1", name: "crop", input: ["x": 1])]),
            ChatMessage(role: .user, parts: [.toolResult(id: "call_1", content: "done", isError: false)]),
        ]
        let body = ChatGPTPlanClient.makeBody(model: "gpt-5.6-sol", system: "sys", messages: msgs,
                                              tools: [ToolSpec(name: "crop", description: "d", parameters: ["type": "object"])])
        XCTAssertEqual(body["stream"], true)
        XCTAssertEqual(body["store"], false)
        XCTAssertEqual(body["instructions"]?.stringValue, "sys")
        XCTAssertEqual(body["reasoning"]?["effort"]?.stringValue, "low")
        let input = body["input"]!.arrayValue!
        XCTAssertEqual(input.map { $0["type"]?.stringValue }, ["message", "message", "function_call", "function_call_output"])
        XCTAssertEqual(input[0]["content"]?[0]?["type"]?.stringValue, "input_image")
        XCTAssertEqual(input[1]["content"]?[0]?["type"]?.stringValue, "output_text")
        XCTAssertEqual(input[2]["namespace"]?.stringValue, "pinpoint")
        XCTAssertEqual(input[2]["arguments"]?.stringValue, #"{"x":1}"#)
        XCTAssertEqual(body["tools"]?[0]?["type"]?.stringValue, "namespace")
        XCTAssertEqual(body["tools"]?[0]?["tools"]?[0]?["name"]?.stringValue, "crop")
    }

    func testCollectStreamEvents() throws {
        let events: [JSONValue] = [
            ["type": "response.output_text.delta", "delta": "Hel"],
            ["type": "response.output_text.delta", "delta": "lo"],
            ["type": "response.output_item.done", "item": ["type": "function_call", "call_id": "c1", "name": "pinpoint.crop", "arguments": #"{"x":5}"#]],
            ["type": "response.completed", "response": ["output": [["type": "function_call", "call_id": "c1", "name": "crop", "arguments": "{}"]]]],
        ]
        let r = try ChatGPTPlanClient.collect(events: events)
        XCTAssertEqual(r.text, "Hello")
        XCTAssertEqual(r.toolCalls, [ToolCall(id: "c1", name: "crop", input: ["x": 5])], "deduped, namespace stripped")
    }

    func testCollectThrowsOnFailure() {
        XCTAssertThrowsError(try ChatGPTPlanClient.collect(events: [["type": "response.failed", "response": ["error": ["message": "limit"]]]]))
    }
}

final class OtherProviderTests: XCTestCase {
    func testOpenRouterHeadersAndDefaults() throws {
        let s = ProviderSettings(kind: .openrouter)
        XCTAssertEqual(s.baseURL, "https://openrouter.ai/api/v1")
        let c = try s.makeClient(apiKey: "or-key") as! OpenAICompatibleClient
        let req = c.makeRequest(system: "", messages: [.user("hi")], tools: [], maxTokens: 10)
        XCTAssertEqual(req.url?.absoluteString, "https://openrouter.ai/api/v1/chat/completions")
        XCTAssertEqual(req.value(forHTTPHeaderField: "authorization"), "Bearer or-key")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Title"), "Pinpoint")
    }

    func testOpenRouterNeedsKey() {
        XCTAssertThrowsError(try ProviderSettings(kind: .openrouter).makeClient(apiKey: ""))
    }

    func testCodexToolProtocol() {
        let prompt = CodexClient.buildPrompt(system: "S", messages: [.user("do it", images: [Data([1])])],
                                             tools: [ToolSpec(name: "crop", description: "Crop", parameters: ["type": "object"])])
        XCTAssertTrue(prompt.contains("- crop: Crop"))
        XCTAssertTrue(prompt.contains("[attached image 1]"))
        let r = CodexClient.parse(#"{"reply":"ok","tool_calls":[{"name":"crop","arguments_json":"{\"x\":2}"}]}"#, expectTools: true)
        XCTAssertEqual(r.text, "ok")
        XCTAssertEqual(r.toolCalls.first?.name, "crop")
        XCTAssertEqual(r.toolCalls.first?.input, ["x": 2])
    }
}

final class ModelPickerTests: XCTestCase {
    let plan = ["gpt-5.6-sol", "gpt-5.6-mini", "gpt-5.5", "gpt-5.6-pro", "gpt-5.1-codex", "gpt-5-nano", "gpt-4.1",
                "gpt-image-1", "gpt-realtime", "o3", "gpt-4o-mini-transcribe"]

    func testPicksNewestFullModelForEdits() {
        XCTAssertEqual(ModelPicker.best(plan), "gpt-5.6-sol")
    }
    func testPicksNewestMiniForFastJobs() {
        XCTAssertEqual(ModelPicker.best(plan, fast: true), "gpt-5.6-mini")
    }
    func testExcludesUnsuitable() {
        let ranked = ModelPicker.ranked(plan)
        XCTAssertFalse(ranked.contains("gpt-image-1"))
        XCTAssertFalse(ranked.contains("gpt-realtime"))
        XCTAssertFalse(ranked.contains("gpt-4o-mini-transcribe"))
        XCTAssertLessThan(ranked.firstIndex(of: "gpt-5.5")!, ranked.firstIndex(of: "gpt-5.6-pro")!, "pro is too slow")
        XCTAssertLessThan(ranked.firstIndex(of: "gpt-5.5")!, ranked.firstIndex(of: "gpt-5.1-codex")!)
    }
    func testAutoSentinels() {
        XCTAssertTrue(ModelPicker.isAuto(""))
        XCTAssertTrue(ModelPicker.isAuto("auto"))
        XCTAssertTrue(ModelPicker.isAuto("auto-fast"))
        XCTAssertFalse(ModelPicker.isAuto("gpt-5.5"))
    }
}

final class UIRegionTests: XCTestCase {
    /// Synthetic app window: toolbar band, left sidebar, content area with a dialog box, status bar.
    func makeWindow() -> CGImage {
        let w = 1000, h = 700
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)   // top-left origin
        func fill(_ r: CGRect, _ g: CGFloat) { ctx.setFillColor(CGColor(gray: g, alpha: 1)); ctx.fill(r) }
        fill(CGRect(x: 0, y: 0, width: w, height: h), 1.0)                  // white
        fill(CGRect(x: 0, y: 0, width: w, height: 60), 0.85)                // toolbar
        fill(CGRect(x: 0, y: 60, width: 220, height: 610), 0.93)            // sidebar
        fill(CGRect(x: 0, y: 670, width: w, height: 30), 0.8)               // status bar
        fill(CGRect(x: 420, y: 250, width: 360, height: 200), 0.75)         // dialog inside content
        return ctx.makeImage()!
    }

    func testFindsToolbarSidebarAndDialog() {
        let img = makeWindow()
        let root = UIRegionDetector.detect(image: img, in: CGRect(x: 0, y: 0, width: 1000, height: 700))
        XCTAssertGreaterThan(root.count, 4)
        // Hovering the toolbar selects (about) the toolbar band.
        let toolbar = root.path(to: CGPoint(x: 500, y: 30)).last!
        XCTAssertEqual(toolbar.minY, 0, accuracy: 3); XCTAssertEqual(toolbar.height, 60, accuracy: 4)
        // Hovering the sidebar selects the sidebar.
        let sidebar = root.path(to: CGPoint(x: 100, y: 300)).last!
        XCTAssertEqual(sidebar.width, 220, accuracy: 4); XCTAssertEqual(sidebar.minY, 61, accuracy: 4)
        // Hovering the dialog selects the dialog, with the content area as its parent.
        let path = root.path(to: CGPoint(x: 600, y: 350))
        let dialog = path.last!
        XCTAssertEqual(dialog.width, 360, accuracy: 6); XCTAssertEqual(dialog.height, 200, accuracy: 6)
        XCTAssertGreaterThanOrEqual(path.count, 3, "window > content > ... > dialog, so scrolling can step out")
    }

    func testPlainImageHasNoChildren() {
        let ctx = CGContext(data: nil, width: 300, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(.white); ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
        let root = UIRegionDetector.detect(image: ctx.makeImage()!, in: CGRect(x: 0, y: 0, width: 300, height: 200))
        XCTAssertEqual(root.children.count, 0)
    }
}

final class HandoffTests: XCTestCase {
    func testNumbersAndMarkdown() {
        let ocr = [OCRLine(text: "Save", rect: CGRect(x: 600, y: 500, width: 60, height: 24)),
                   OCRLine(text: "Error: token expired", rect: CGRect(x: 100, y: 100, width: 300, height: 30))]
        var arrow = Annotation(kind: .arrow, start: CGPoint(x: 500, y: 400), end: CGPoint(x: 610, y: 505))
        arrow.note = "This button does nothing when clicked"
        let plain = Annotation(kind: .rectangle, start: CGPoint(x: 90, y: 90), end: CGPoint(x: 420, y: 140))
        var pin = Annotation(kind: .note, start: CGPoint(x: 120, y: 110), end: CGPoint(x: 120, y: 110))
        pin.note = "Started after the last deploy"
        let anns = [arrow, plain, pin]
        let nums = Renderer.noteNumbers(anns)
        XCTAssertEqual(nums[arrow.id], 1); XCTAssertEqual(nums[pin.id], 2); XCTAssertNil(nums[plain.id])
        let meta = CaptureMeta(name: "Login bug", sourceApp: "Safari", width: 1000, height: 800)
        let md = Handoff.markdown(meta: meta, annotations: anns, imagePath: "/tmp/x.png", ocr: ocr)
        XCTAssertTrue(md.contains("Image: /tmp/x.png"))
        XCTAssertTrue(md.contains("1. Arrow pointing at “Save”"), md)
        XCTAssertTrue(md.contains("This button does nothing"))
        XCTAssertTrue(md.contains("2. Pin at “Error: token expired”"), md)
        XCTAssertTrue(md.contains("Other markup: Outlined area around “Error: token expired”"), md)
    }

    func testNotesRenderAndDecodeOldMeta() throws {
        let base = makeImage()
        var a = Annotation(kind: .arrow, start: CGPoint(x: 100, y: 100), end: CGPoint(x: 300, y: 200)); a.note = "x"
        let pin = Annotation(kind: .note, start: CGPoint(x: 400, y: 300), end: CGPoint(x: 400, y: 300), note: "y")
        XCTAssertNotNil(Renderer.flatten(base: base, annotations: [a, pin], crop: nil))
        // Captures saved before notes existed still load.
        let old = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"arrow","start":[1,2],"end":[3,4],"color":{"r":1,"g":0,"b":0,"a":1},"lineWidth":4,"fontSize":28}"#
        let decoded = try JSONDecoder().decode(Annotation.self, from: Data(old.utf8))
        XCTAssertNil(decoded.note)
    }
}

final class NotesPanelTests: XCTestCase {
    func testPanelAddedOnlyWhenThereAreNotes() {
        let base = makeImage(width: 800, height: 600)
        let plain = [Annotation(kind: .arrow, start: CGPoint(x: 10, y: 10), end: CGPoint(x: 200, y: 200))]
        XCTAssertEqual(Renderer.withNotesPanel(base, annotations: plain).height, 600)
        var a = plain[0]; a.note = "The Save button doesn't respond after the session expires. Repro: log in, wait 30 minutes, click Save."
        let pin = Annotation(kind: .note, start: CGPoint(x: 400, y: 300), end: CGPoint(x: 400, y: 300), note: "Console shows a 401 here")
        let out = Renderer.withNotesPanel(base, annotations: [a, pin])
        XCTAssertEqual(out.width, 800)
        XCTAssertGreaterThan(out.height, 600 + 60)
        // Original pixels are untouched at the top.
        let rep = NSBitmapImageRep(cgImage: out)
        XCTAssertGreaterThan(rep.colorAt(x: 700, y: 50)!.brightnessComponent, 0.9)
        // Sample for eyeballing the layout.
        let flat = Renderer.flatten(base: base, annotations: [a, pin], crop: nil)!
        try? ImageFiles.write(Renderer.withNotesPanel(flat, annotations: [a, pin]),
                              to: FileManager.default.temporaryDirectory.appendingPathComponent("pinpoint-notes-panel-sample.png"))
    }
}
