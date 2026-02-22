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
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
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
            dependencies: [
                "LambdaDeckCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
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
