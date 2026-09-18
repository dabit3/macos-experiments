// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PocketPressCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PocketPressCore", targets: ["PocketPressCore"])],
    targets: [
        .target(name: "PocketPressCore", path: "Core"),
        .testTarget(
            name: "PocketPressCoreTests", dependencies: ["PocketPressCore"],
            path: "Tests/PocketPressCoreTests"),
    ]
)
