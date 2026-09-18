// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PatchworkCore",
  platforms: [.macOS(.v14), .iOS(.v17)],
  products: [.library(name: "PatchworkCore", targets: ["PatchworkCore"])],
  targets: [
    .target(name: "PatchworkCore"),
    .testTarget(name: "PatchworkCoreTests", dependencies: ["PatchworkCore"]),
  ],
  swiftLanguageModes: [.v5]
)
