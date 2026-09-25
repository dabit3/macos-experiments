// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "FrameForgeCore",
  products: [.library(name: "FrameForgeCore", targets: ["FrameForgeCore"])],
  targets: [
    .target(
      name: "FrameForgeCore",
      path: "Sources",
      exclude: ["StudioStore.swift", "ArtworkRenderer.swift", "FrameForgeApp.swift"],
      sources: ["AnimationModel.swift"]
    ),
    .testTarget(name: "FrameForgeCoreTests", dependencies: ["FrameForgeCore"]),
  ]
)
