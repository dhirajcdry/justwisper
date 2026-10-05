// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Wispr",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", exact: "1.1.0")
    ],
    targets: [
        .executableTarget(
            name: "Wispr",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift")
            ],
            path: "Sources/Wispr"
        ),
        .testTarget(
            name: "WisprTests",
            dependencies: ["Wispr"],
            path: "Tests/WisprTests"
        )
    ]
)
