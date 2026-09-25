// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Loom",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "Loom", targets: ["Loom"])],
  targets: [
    .target(name: "LoomCore"),
    .executableTarget(
      name: "Loom", dependencies: ["LoomCore"],
      resources: [.copy("Resources")]
    ),
    .testTarget(name: "LoomCoreTests", dependencies: ["LoomCore"]),
  ],
  swiftLanguageModes: [.v5]
)
