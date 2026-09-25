// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "HearthCore",
  platforms: [.macOS(.v14), .iOS(.v17)],
  products: [.library(name: "HearthCore", targets: ["HearthCore"])],
  targets: [
    .target(name: "HearthCore", resources: [.process("Resources")]),
    .testTarget(name: "HearthCoreTests", dependencies: ["HearthCore"]),
  ]
)
