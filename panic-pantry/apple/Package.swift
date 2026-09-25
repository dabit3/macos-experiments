// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "PanicPantry",
  platforms: [.macOS(.v14), .iOS(.v17)],
  products: [.library(name: "PantryKit", targets: ["PantryKit"])],
  targets: [
    .target(name: "PantryKit", resources: [.process("Resources")]),
    .testTarget(
      name: "PantryKitTests", dependencies: ["PantryKit"], resources: [.process("Fixtures")]),
  ]
)
