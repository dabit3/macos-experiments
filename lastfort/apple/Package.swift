// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "LastfortKit",
  platforms: [.macOS(.v14), .iOS(.v17)],
  products: [.library(name: "LastfortKit", targets: ["LastfortKit"])],
  targets: [
    .target(name: "LastfortKit", path: "Sources/Model"),
    .testTarget(
      name: "LastfortKitTests", dependencies: ["LastfortKit"],
      path: "Tests/LastfortKitTests", resources: [.copy("Fixtures")]),
  ]
)
