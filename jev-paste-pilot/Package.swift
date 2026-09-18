// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "PastePilot",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "PastePilot", targets: ["PastePilot"]),
    .executable(name: "VendorForm", targets: ["VendorForm"]),
  ],
  targets: [
    .target(name: "PasteCore"),
    .executableTarget(name: "PastePilot", dependencies: ["PasteCore"]),
    .executableTarget(name: "VendorForm"),
    .testTarget(name: "PasteCoreTests", dependencies: ["PasteCore"]),
  ]
)
