// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TerraCore",
  platforms: [.macOS(.v14), .iOS(.v17)],
  products: [.library(name: "TerraCore", targets: ["TerraCore"])],
  targets: [
    .target(name: "TerraCore"),
    .target(
      name: "TerraStudio", dependencies: ["TerraCore"], path: "App",
      exclude: ["Info.plist", "TerraTableApp.swift", "TerrainScene.swift"]),
    .testTarget(name: "TerraCoreTests", dependencies: ["TerraCore"]),
    .testTarget(name: "TerraStudioTests", dependencies: ["TerraStudio", "TerraCore"]),
  ]
)
