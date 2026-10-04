// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "OtterFlapRules",
  products: [.library(name: "OtterFlapRules", targets: ["OtterFlapRules"])],
  targets: [
    .target(name: "OtterFlapRules", path: "Sources/Core"),
    .testTarget(name: "OtterFlapRulesTests", dependencies: ["OtterFlapRules"], path: "Tests"),
  ]
)
