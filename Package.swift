// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenCanvas",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "OpenCanvas",
            targets: ["OpenCanvas"]
        )
    ],
    targets: [
        .executableTarget(
            name: "OpenCanvas",
            dependencies: [],
            path: "Sources/OpenCanvas",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "OpenCanvasTests",
            dependencies: [],
            path: "Tests/OpenCanvasTests"
        )
    ]
)
