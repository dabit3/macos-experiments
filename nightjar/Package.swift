// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Nightjar",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "Nightjar", targets: ["NightjarApp"])],
  targets: [
    .target(name: "NightjarCore"),
    .executableTarget(name: "NightjarApp", dependencies: ["NightjarCore"]),
    .testTarget(name: "NightjarCoreTests", dependencies: ["NightjarCore"]),
  ],
  swiftLanguageModes: [.v5]
)
