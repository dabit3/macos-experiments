// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ShareStage",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "ShareStage", targets: ["ShareStage"])],
  targets: [
    .target(name: "StageCore"),
    .executableTarget(name: "ShareStage", dependencies: ["StageCore"]),
    .testTarget(name: "StageCoreTests", dependencies: ["StageCore"]),
  ],
  swiftLanguageModes: [.v5]
)
