// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "CableChaosRules",
  products: [.library(name: "CableChaosCore", targets: ["CableChaosCore"])],
  targets: [
    .target(name: "CableChaosCore", path: "Core"),
    .testTarget(name: "CableChaosTests", dependencies: ["CableChaosCore"], path: "Tests"),
  ]
)
