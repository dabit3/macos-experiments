// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "GTCBingoRules",
  products: [.library(name: "GTCBingoCore", targets: ["GTCBingoCore"])],
  targets: [
    .target(name: "GTCBingoCore", path: "Core"),
    .testTarget(name: "GTCBingoTests", dependencies: ["GTCBingoCore"], path: "Tests"),
  ]
)
