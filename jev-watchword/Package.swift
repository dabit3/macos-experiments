// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Watchword",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "Watchword", targets: ["Watchword"])],
  targets: [
    .target(name: "WatchwordCore"),
    .executableTarget(name: "Watchword", dependencies: ["WatchwordCore"]),
    .testTarget(name: "WatchwordCoreTests", dependencies: ["WatchwordCore"]),
  ],
  swiftLanguageModes: [.v5]
)
