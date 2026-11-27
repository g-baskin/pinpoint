// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Pinpoint",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Pinpoint", targets: ["Pinpoint"])],
    targets: [
        .target(name: "PinpointCore"),
        .executableTarget(name: "Pinpoint", dependencies: ["PinpointCore"]),
        .testTarget(name: "PinpointCoreTests", dependencies: ["PinpointCore"]),
    ]
)
