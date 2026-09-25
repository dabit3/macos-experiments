// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PrismCore",
  platforms: [.macOS(.v13)],
  products: [.library(name: "PrismCore", targets: ["PrismCore"])],
  targets: [
    .target(name: "PrismCore", path: "Sources/Core"),
    .testTarget(name: "PrismCoreTests", dependencies: ["PrismCore"], path: "Tests"),
  ]
)
