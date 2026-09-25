// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Keystone",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "Keystone", targets: ["Keystone"])],
  targets: [
    .target(name: "KeystoneCore"),
    .executableTarget(name: "Keystone", dependencies: ["KeystoneCore"]),
    .testTarget(name: "KeystoneCoreTests", dependencies: ["KeystoneCore"]),
  ]
)
