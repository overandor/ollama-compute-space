// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OllamaMacOSApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "OllamaMacOSApp",
            targets: ["OllamaMacOSApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "OllamaMacOSApp",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            path: "Sources"
        )
    ]
)
