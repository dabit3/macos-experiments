// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "RoomlightCore",
  platforms: [.macOS(.v14)],
  products: [.library(name: "RoomlightCore", targets: ["RoomlightCore"])],
  targets: [
    .target(name: "RoomlightCore"),
    .testTarget(name: "RoomlightCoreTests", dependencies: ["RoomlightCore"]),
  ]
)
