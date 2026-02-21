// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LambdaDeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LambdaDeckCore",
            targets: ["LambdaDeckCore"]
        ),
        .executable(
            name: "lambdadeck",
            targets: ["LambdaDeckCLI"]
        )
    ],
    targets: [
        .target(
            name: "LambdaDeckCore"
        ),
        .executableTarget(
            name: "LambdaDeckCLI",
            dependencies: ["LambdaDeckCore"]
        ),
        .testTarget(
            name: "LambdaDeckCoreTests",
            dependencies: ["LambdaDeckCore"]
        ),
        .testTarget(
            name: "LambdaDeckCLITests",
            dependencies: ["LambdaDeckCLI"]
        ),
        .testTarget(
            name: "LambdaDeckIntegrationTests",
            dependencies: ["LambdaDeckCLI", "LambdaDeckCore"]
        )
    ]
)
