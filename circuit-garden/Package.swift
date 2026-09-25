// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "CircuitGarden",
  platforms: [.macOS(.v14)],
  products: [.library(name: "CircuitCore", targets: ["CircuitCore"])],
  targets: [
    .target(name: "CircuitCore", path: "Sources/Core"),
    .testTarget(name: "CircuitCoreTests", dependencies: ["CircuitCore"]),
  ]
)
