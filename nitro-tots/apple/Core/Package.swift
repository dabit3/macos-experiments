// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "NitroCore",
  platforms: [.macOS(.v14), .iOS(.v17)],
  products: [.library(name: "NitroCore", targets: ["NitroCore"])],
  targets: [
    .target(name: "NitroCore", resources: [.process("Resources")]),
    .testTarget(
      name: "NitroCoreTests", dependencies: ["NitroCore"], resources: [.copy("fixtures.json")]),
  ]
)
