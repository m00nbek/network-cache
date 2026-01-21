// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkCache",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "NetworkCache",
            targets: ["NetworkCache"]),
    ],
    targets: [
        .target(
            name: "NetworkCache",
            path: "Sources/NetworkCache"
        ),
        .testTarget(
            name: "NetworkCacheTests",
            dependencies: ["NetworkCache"],
            path: "Tests/NetworkCacheTests"
        )
    ]
)
