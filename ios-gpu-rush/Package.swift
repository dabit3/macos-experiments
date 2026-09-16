// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "GPURushRules",
  products: [.library(name: "GPURushCore", targets: ["GPURushCore"])],
  targets: [
    .target(name: "GPURushCore", path: "Core"),
    .testTarget(name: "GPURushTests", dependencies: ["GPURushCore"], path: "Tests"),
  ]
)
