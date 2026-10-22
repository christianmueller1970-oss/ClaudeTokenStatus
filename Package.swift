// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeTokenStatus",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "StatusCore", targets: ["StatusCore"]),
    ],
    targets: [
        .target(name: "StatusCore"),
        .testTarget(
            name: "StatusCoreTests",
            dependencies: ["StatusCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
