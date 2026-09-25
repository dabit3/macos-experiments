// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AfterglowCore",
  platforms: [.macOS(.v14)],
  products: [.library(name: "AfterglowCore", targets: ["AfterglowCore"])],
  targets: [
    .target(name: "AfterglowCore", path: "AfterglowCore"),
    .testTarget(name: "AfterglowCoreTests", dependencies: ["AfterglowCore"], path: "Tests"),
  ],
  swiftLanguageModes: [.v5]
)
