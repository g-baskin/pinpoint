import Foundation
import XCTest
@testable import PinpointCore

/// Answers every request from the current handler, so client network paths run without the internet.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (code, data) = Self.handler?(request) ?? (500, Data())
        let resp = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class ClientNetworkTests: XCTestCase {
    override func tearDown() { StubURLProtocol.handler = nil }

    func anthropic() -> AnthropicClient {
        var c = AnthropicClient(apiKey: "k", model: "m", baseURL: URL(string: "https://api.example.test")!)
        c.session = StubURLProtocol.session()
        return c
    }

    func openAI() -> OpenAICompatibleClient {
        var c = OpenAICompatibleClient(apiKey: "k", model: "m", baseURL: URL(string: "https://api.example.test/v1")!)
        c.session = StubURLProtocol.session()
        return c
    }

    func testAnthropicSendRoundTrip() async throws {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/v1/messages")
            return (200, Data(#"{"content":[{"type":"text","text":"hello"}],"stop_reason":"end_turn"}"#.utf8))
        }
        let text = try await anthropic().ask(system: "s", prompt: "hi")
        XCTAssertEqual(text, "hello")
    }

    func testOpenAISendRoundTrip() async throws {
        StubURLProtocol.handler = { _ in
            (200, Data(#"{"choices":[{"message":{"role":"assistant","content":"hey"},"finish_reason":"stop"}]}"#.utf8))
        }
        let text = try await openAI().ask(system: "s", prompt: "hi")
        XCTAssertEqual(text, "hey")
    }

    func testHTTPErrorSurfacesProviderMessage() async {
        StubURLProtocol.handler = { _ in (401, Data(#"{"error":{"message":"invalid x-api-key"}}"#.utf8)) }
        do {
            _ = try await anthropic().ask(system: "", prompt: "hi")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual("\(error)".contains("HTTP 401: invalid x-api-key"), true, "\(error)")
        }
    }

    func testHTTPErrorWithPlainBodyKeepsBody() async {
        StubURLProtocol.handler = { _ in (503, Data("upstream down".utf8)) }
        do {
            _ = try await openAI().ask(system: "", prompt: "hi")
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("HTTP 503: upstream down"), "\(error)")
        }
    }
}

final class LibraryDeleteTests: XCTestCase {
    func testDeleteRemovesOnlyThatCapture() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pinpoint-del-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = LibraryStore(root: dir)
        let keep = try store.create(image: makeImage(), name: "Keep")
        let gone = try store.create(image: makeImage(), name: "Gone")
        let trashed = try store.delete(gone.id)
        if let trashed { try? FileManager.default.removeItem(at: trashed) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.folder(gone.id).path))
        XCTAssertEqual(store.loadAll().map(\.id), [keep.id])
        XCTAssertNotNil(store.original(keep.id))
    }
}

/// Always asks for another tool call, or throws, to exercise the loop's other exits.
struct LoopingClient: LLMClient {
    var fail = false
    func send(system: String, messages: [ChatMessage], tools: [ToolSpec], maxTokens: Int) async throws -> ChatResponse {
        if fail { throw LLMError("boom") }
        return ChatResponse(parts: [.toolUse(id: UUID().uuidString, name: "add_annotation", input: ["kind": "step", "x1": 10, "y1": 10])],
                            stopReason: "tool_use")
    }
}

final class AgentExitTests: XCTestCase {
    let state = AgentState(annotations: [], crop: nil, name: "x", tags: [], imageSize: CGSize(width: 400, height: 300))
    let analysis = Analysis(lines: [], sensitive: [])

    func testStopsAfterMaxSteps() async throws {
        let r = try await EditAgent(client: LoopingClient(), maxSteps: 3)
            .run(instruction: "go", image: makeImage(width: 400, height: 300), analysis: analysis, state: state)
        XCTAssertEqual(r.reply, "Stopped after 3 steps.")
        XCTAssertEqual(r.state.annotations.count, 3)
    }

    func testClientErrorPropagates() async {
        do {
            _ = try await EditAgent(client: LoopingClient(fail: true))
                .run(instruction: "go", image: makeImage(width: 400, height: 300), analysis: analysis, state: state)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue("\(error)".contains("boom"), "\(error)")
        }
    }
}

final class MarkdownSafetyTests: XCTestCase {
    func testEscapesHTMLAndQuotes() {
        let html = Markdown.toHTML(#"<script>alert(1)</script> ![x" onerror="alert(1)](a.png)"#)
        XCTAssertFalse(html.contains("<script>"))
        XCTAssertFalse(html.contains(#"" onerror=""#))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
    }

    func testBlocksUnsafeLinkSchemes() {
        for bad in ["javascript:alert(1)", "JavaScript:alert(1)", "data:text/html,hi", "vbscript:x"] {
            let html = Markdown.toHTML("[click](\(bad))")
            XCTAssertFalse(html.contains("<a "), "\(bad) became a link: \(html)")
        }
    }

    func testKeepsSafeLinks() {
        XCTAssertTrue(Markdown.toHTML("[docs](https://example.com/a)").contains(#"<a href="https://example.com/a">docs</a>"#))
        XCTAssertTrue(Markdown.toHTML("[mail](mailto:a@b.co)").contains(#"<a href="mailto:a@b.co">"#))
        XCTAssertTrue(Markdown.toHTML("![Step 1](images/step-1.png)").contains(#"<img alt="Step 1" src="images/step-1.png">"#))
    }
}
