// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ShotboardCore",
  platforms: [.macOS(.v14)],
  products: [.library(name: "ShotboardCore", targets: ["ShotboardCore"])],
  targets: [
    .target(name: "ShotboardCore"),
    .testTarget(name: "ShotboardCoreTests", dependencies: ["ShotboardCore"]),
  ]
)
