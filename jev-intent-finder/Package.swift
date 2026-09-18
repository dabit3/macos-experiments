// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "IntentFinder",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "IntentFinder", targets: ["IntentFinder"]),
    .executable(name: "intent-check", targets: ["IntentCheck"]),
  ],
  targets: [
    .target(name: "IntentCore", resources: [.process("Resources")]),
    .executableTarget(name: "IntentFinder", dependencies: ["IntentCore"]),
    .executableTarget(name: "IntentCheck", dependencies: ["IntentCore"]),
    .testTarget(name: "IntentCoreTests", dependencies: ["IntentCore"]),
  ]
)
