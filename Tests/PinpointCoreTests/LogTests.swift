import Foundation
import XCTest

@testable import PinpointCore

/// The README's `log show` command filters on this subsystem, so it must stay the app's bundle id.
final class LogTests: XCTestCase {
    func testSubsystemMatchesBundleIdentifier() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/Info.plist"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, PinpointLog.subsystem)
    }
}
