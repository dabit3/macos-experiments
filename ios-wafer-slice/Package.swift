// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "WaferSliceCore",
  products: [.library(name: "WaferSliceCore", targets: ["WaferSliceCore"])],
  targets: [
    .target(name: "WaferSliceCore", path: "Core"),
    .testTarget(name: "WaferSliceCoreTests", dependencies: ["WaferSliceCore"], path: "Tests"),
  ]
)
