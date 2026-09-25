// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "GrooveboxCore",
  platforms: [.macOS(.v13)],
  products: [.library(name: "GrooveboxCore", targets: ["GrooveboxCore"])],
  targets: [
    .target(
      name: "GrooveboxCore", path: "Sources",
      exclude: [
        "AudioEngine.swift", "InstrumentModel.swift", "InstrumentView.swift", "GrooveboxApp.swift",
      ],
      sources: ["Core.swift"]),
    .testTarget(name: "GrooveboxCoreTests", dependencies: ["GrooveboxCore"], path: "Tests"),
  ]
)
