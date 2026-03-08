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
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "OpenCanvas",
            dependencies: ["SwiftTerm"],
            path: "Sources/OpenCanvas",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "OpenCanvasTests",
            dependencies: ["OpenCanvas"],
            path: "Tests/OpenCanvasTests"
        )
    ]
)
