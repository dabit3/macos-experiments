// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "Brickfolk",
  platforms: [.macOS(.v14), .iOS(.v17)],
  products: [
    .library(name: "BrickfolkCore", targets: ["BrickfolkCore"]),
    .executable(name: "brickfolk-protocol-probe", targets: ["ProtocolProbe"]),
  ],
  targets: [
    .target(name: "BrickfolkCore", resources: [.process("Resources")]),
    .executableTarget(name: "ProtocolProbe", dependencies: ["BrickfolkCore"]),
    .testTarget(name: "BrickfolkCoreTests", dependencies: ["BrickfolkCore"]),
  ]
)
