// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Cutline",
  platforms: [.macOS(.v15)],
  products: [.executable(name: "Cutline", targets: ["Cutline"])],
  targets: [
    .executableTarget(name: "Cutline", swiftSettings: [.swiftLanguageMode(.v5)]),
    .testTarget(name: "CutlineTests", dependencies: ["Cutline"]),
  ]
)
