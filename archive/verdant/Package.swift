// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Verdant",
  platforms: [.macOS(.v14)],
  products: [.library(name: "VerdantCore", targets: ["VerdantCore"])],
  targets: [
    .target(name: "VerdantCore", path: "Sources/Core"),
    .testTarget(
      name: "VerdantCoreTests", dependencies: ["VerdantCore"], path: "Tests/VerdantCoreTests"),
  ]
)
