// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OtterRules",
    products: [.library(name: "OtterRules", targets: ["OtterRules"])],
    targets: [
        .target(name: "OtterRules", path: "Sources/Core"),
        .testTarget(name: "OtterRulesTests", dependencies: ["OtterRules"], path: "Tests"),
    ]
)
