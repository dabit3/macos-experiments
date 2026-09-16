// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "PocketDGXRules",
  products: [.library(name: "PocketDGXCore", targets: ["PocketDGXCore"])],
  targets: [
    .target(name: "PocketDGXCore", path: "Core"),
    .testTarget(name: "PocketDGXTests", dependencies: ["PocketDGXCore"], path: "Tests"),
  ]
)
