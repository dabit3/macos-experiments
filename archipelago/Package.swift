// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ArchipelagoCore",
  products: [.library(name: "ArchipelagoCore", targets: ["ArchipelagoCore"])],
  targets: [
    .target(name: "ArchipelagoCore", path: "Sources/Core"),
    .testTarget(name: "ArchipelagoCoreTests", dependencies: ["ArchipelagoCore"]),
  ]
)
