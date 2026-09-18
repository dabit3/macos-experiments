// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "FairshareCore",
  platforms: [.macOS(.v14)],
  products: [.library(name: "FairshareCore", targets: ["FairshareCore"])],
  targets: [
    .target(name: "FairshareCore", path: "Core"),
    .testTarget(name: "FairshareCoreTests", dependencies: ["FairshareCore"]),
  ]
)
