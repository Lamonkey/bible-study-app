// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ChaJing",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ChaJing",
            path: "Sources/ChaJing",
            resources: [.copy("Resources/cus.json")],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "ChaJingTests",
            dependencies: ["ChaJing"],
            path: "Tests/ChaJingTests"
        ),
    ]
)
