// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Wavecraft",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "Wavecraft", targets: ["Wavecraft"])],
  targets: [
    .target(name: "WavecraftCore"),
    .executableTarget(name: "Wavecraft", dependencies: ["WavecraftCore"]),
    .testTarget(name: "WavecraftCoreTests", dependencies: ["WavecraftCore"]),
  ]
)
