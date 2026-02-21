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
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "LambdaDeckCore",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird")
            ]
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
            dependencies: [
                "LambdaDeckCLI",
                "LambdaDeckCore",
                .product(name: "HummingbirdTesting", package: "hummingbird")
            ]
        )
    ]
)
