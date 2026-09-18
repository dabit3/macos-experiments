// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TaskDeck",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "TaskDeck", targets: ["TaskDeck"])],
  targets: [
    .target(name: "TaskDeckCore"),
    .executableTarget(name: "TaskDeck", dependencies: ["TaskDeckCore"]),
    .testTarget(name: "TaskDeckCoreTests", dependencies: ["TaskDeckCore"]),
  ],
  swiftLanguageModes: [.v5]
)
