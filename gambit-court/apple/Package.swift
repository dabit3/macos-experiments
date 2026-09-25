// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GambitCourt",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "CourtCore", targets: ["CourtCore"])],
    targets: [
        .target(name: "CourtCore"),
        .testTarget(name: "CourtCoreTests", dependencies: ["CourtCore"]),
    ]
)
