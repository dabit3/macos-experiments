// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "LanternfallRules",
  products: [.library(name: "LanternfallCore", targets: ["LanternfallCore"])],
  targets: [
    .target(name: "LanternfallCore", path: "Core"),
    .testTarget(name: "LanternfallTests", dependencies: ["LanternfallCore"], path: "Tests"),
  ]
)
