// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeTokenStatus",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "StatusCore", targets: ["StatusCore"]),
        .executable(name: "claude-status-bridge", targets: ["claude-status-bridge"]),
    ],
    targets: [
        .target(name: "StatusCore"),
        .executableTarget(name: "claude-status-bridge", dependencies: ["StatusCore"]),
        .testTarget(
            name: "StatusCoreTests",
            dependencies: ["StatusCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
