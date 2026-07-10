// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PrismetShared",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PrismetShared",
            targets: ["PrismetShared"]
        )
    ],
    targets: [
        .target(name: "PrismetShared"),
        .testTarget(
            name: "PrismetSharedTests",
            dependencies: ["PrismetShared"]
        )
    ]
)
