// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenCodeCanvas",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "OpenCodeCanvas",
            targets: ["OpenCodeCanvas"]
        )
    ],
    targets: [
        .executableTarget(
            name: "OpenCodeCanvas",
            dependencies: [],
            path: "Sources/OpenCodeCanvas",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "OpenCodeCanvasTests",
            dependencies: [],
            path: "Tests/OpenCodeCanvasTests"
        )
    ]
)
