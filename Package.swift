// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Zoomies",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Zoomies", targets: ["Zoomies"])],
    targets: [
        .target(name: "ZoomiesCore"),
        .executableTarget(name: "Zoomies", dependencies: ["ZoomiesCore"]),
        .testTarget(name: "ZoomiesCoreTests", dependencies: ["ZoomiesCore"]),
    ]
)
