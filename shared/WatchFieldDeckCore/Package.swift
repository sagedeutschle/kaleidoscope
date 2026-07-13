// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WatchFieldDeckCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v11),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WatchFieldDeckCore", targets: ["WatchFieldDeckCore"]),
    ],
    targets: [
        .target(name: "WatchFieldDeckCore"),
        .testTarget(name: "WatchFieldDeckCoreTests", dependencies: ["WatchFieldDeckCore"]),
    ]
)
