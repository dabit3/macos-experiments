// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "InkAtlasCore",
  platforms: [.macOS(.v14)],
  products: [.library(name: "InkAtlasCore", targets: ["InkAtlasCore"])],
  targets: [
    .target(name: "InkAtlasCore", path: "Core"),
    .testTarget(name: "InkAtlasCoreTests", dependencies: ["InkAtlasCore"], path: "Tests"),
  ]
)
