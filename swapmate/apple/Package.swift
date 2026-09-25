// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "SwapmateKit",
  platforms: [.macOS(.v14), .iOS(.v17)],
  products: [.library(name: "SwapmateKit", targets: ["SwapmateKit"])],
  targets: [
    .target(name: "SwapmateKit"),
    .testTarget(
      name: "SwapmateKitTests", dependencies: ["SwapmateKit"], resources: [.copy("Fixtures")]),
  ]
)
