// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitHubTray",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "GitHubTray",
            targets: ["GitHubTray"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "GitHubTray",
            dependencies: [],
            path: "Sources",
            linkerSettings: [
                .linkedFramework("Cocoa"),
            ]
        ),
    ]
)
