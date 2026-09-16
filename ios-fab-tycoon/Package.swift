// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "FabTycoonRules",
  products: [.library(name: "FabTycoonCore", targets: ["FabTycoonCore"])],
  targets: [
    .target(name: "FabTycoonCore", path: "Core"),
    .testTarget(name: "FabTycoonTests", dependencies: ["FabTycoonCore"], path: "Tests"),
  ]
)
