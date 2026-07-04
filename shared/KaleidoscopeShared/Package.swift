// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KaleidoscopeShared",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "KaleidoscopeShared",
            targets: ["KaleidoscopeShared"]
        )
    ],
    targets: [
        .target(name: "KaleidoscopeShared"),
        .testTarget(
            name: "KaleidoscopeSharedTests",
            dependencies: ["KaleidoscopeShared"]
        )
    ]
)
