// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MiseCore",
  platforms: [.macOS(.v14)],
  products: [.library(name: "MiseCore", targets: ["MiseCore"])],
  targets: [
    .target(name: "MiseCore", path: "Sources/MiseCore"),
    .testTarget(name: "MiseCoreTests", dependencies: ["MiseCore"]),
  ]
)
