// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Kerf",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "Kerf", targets: ["Kerf"])],
  targets: [
    .target(name: "KerfCore"),
    .executableTarget(name: "Kerf", dependencies: ["KerfCore"]),
    .testTarget(name: "KerfCoreTests", dependencies: ["KerfCore"]),
  ]
)
