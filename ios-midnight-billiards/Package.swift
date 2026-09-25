// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MidnightRules",
    platforms: [.macOS(.v13)],
    products: [.library(name: "MidnightRules", targets: ["MidnightRules"])],
    targets: [
        .target(
            name: "MidnightRules",
            path: "Sources",
            exclude: ["Design.swift", "MidnightApp.swift", "Session.swift", "TableView.swift"],
            sources: ["Physics.swift", "GameEngine.swift"]
        ),
        .testTarget(name: "MidnightRulesTests", dependencies: ["MidnightRules"], path: "Tests"),
    ]
)
