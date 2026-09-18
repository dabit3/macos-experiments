// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PostcardRules",
    platforms: [.macOS(.v13)],
    products: [.library(name: "PostcardRules", targets: ["PostcardRules"])],
    targets: [
        .target(name: "PostcardRules", path: "Sources/Core"),
        .testTarget(name: "PostcardRulesTests", dependencies: ["PostcardRules"], path: "Tests", exclude: ["App"]),
    ]
)
