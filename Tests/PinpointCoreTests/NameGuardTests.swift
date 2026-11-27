import Foundation
import XCTest

/// The app's former name is retired; this keeps it out of every tracked file.
final class NameGuardTests: XCTestCase {
    func testFormerNameAppearsNowhere() throws {
        let retired = "zoo" + "mies"  // split so this file doesn't match itself
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let git = Process()
        git.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        git.arguments = ["-C", root.path, "ls-files", "-z", "--cached", "--others", "--exclude-standard"]
        let pipe = Pipe()
        git.standardOutput = pipe
        do { try git.run() } catch { throw XCTSkip("git not available: \(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        git.waitUntilExit()
        try XCTSkipIf(git.terminationStatus != 0, "not a git checkout")
        let files = String(decoding: data, as: UTF8.self).split(separator: "\0").map(String.init)
        XCTAssertFalse(files.isEmpty)
        var hits: [String] = []
        for path in files where !path.hasPrefix(".gg") {
            if path.lowercased().contains(retired) { hits.append(path); continue }
            guard let text = try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8) else { continue }
            if text.lowercased().contains(retired) { hits.append(path) }
        }
        XCTAssertEqual(hits, [], "Use the name Pinpoint; the former name was found in these files")
    }
}
