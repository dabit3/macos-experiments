// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "CudaBlocksRules",
  products: [.library(name: "CudaBlocksCore", targets: ["CudaBlocksCore"])],
  targets: [
    .target(name: "CudaBlocksCore", path: "Core"),
    .testTarget(name: "CudaBlocksTests", dependencies: ["CudaBlocksCore"], path: "Tests"),
  ]
)
