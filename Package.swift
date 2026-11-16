// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AppSweeper",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AppSweeper", targets: ["AppSweeper"])
    ],
    targets: [
        .target(name: "AppSweeperCore"),
        .executableTarget(name: "AppSweeper", dependencies: ["AppSweeperCore"],
                          resources: [.copy("Resources/AppIcon.png")]),
        .executableTarget(name: "appsweeper-scan", dependencies: ["AppSweeperCore"]),
        .testTarget(name: "AppSweeperCoreTests", dependencies: ["AppSweeperCore"])
    ]
)
