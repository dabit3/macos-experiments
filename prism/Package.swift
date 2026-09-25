// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Prism",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "Prism", targets: ["Prism"])],
  targets: [
    .target(name: "PrismCore"),
    .executableTarget(
      name: "Prism",
      dependencies: ["PrismCore"],
      resources: [.process("Resources")]
    ),
    .testTarget(name: "PrismCoreTests", dependencies: ["PrismCore"]),
  ],
  swiftLanguageModes: [.v5]
)
