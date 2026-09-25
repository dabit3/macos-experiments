// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Railway",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "RailwayCore", targets: ["RailwayCore"]),
    .executable(name: "Railway", targets: ["Railway"]),
  ],
  targets: [
    .target(name: "RailwayCore"),
    .executableTarget(name: "Railway", dependencies: ["RailwayCore"]),
    .testTarget(name: "RailwayCoreTests", dependencies: ["RailwayCore"]),
  ]
)
