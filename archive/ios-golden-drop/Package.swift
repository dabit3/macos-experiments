// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "GoldenDropRules",
  platforms: [.macOS(.v12), .iOS(.v17)],
  products: [.library(name: "GoldenDropRules", targets: ["GoldenDropRules"])],
  targets: [
    .target(
      name: "GoldenDropRules", path: "Sources",
      exclude: ["GameStore.swift", "GoldenDropApp.swift", "TheaterArt.swift"],
      sources: ["GameRules.swift"]),
    .testTarget(name: "GoldenDropRulesTests", dependencies: ["GoldenDropRules"], path: "Tests"),
  ],
  swiftLanguageModes: [.v5]
)
