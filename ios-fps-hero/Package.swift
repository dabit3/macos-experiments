// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "FPSHeroRules",
  products: [.library(name: "FPSHeroCore", targets: ["FPSHeroCore"])],
  targets: [
    .target(name: "FPSHeroCore", path: "Core"),
    .testTarget(name: "FPSHeroTests", dependencies: ["FPSHeroCore"], path: "Tests"),
  ]
)
