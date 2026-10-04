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
        .target(
            name: "PrismetShared",
            // Uncle Scam's offline fallback: the website's own data files and seal (scripts/uncle-scam-golden.mjs copies them).
            // Not a folder named "Resources": at the root of an iOS bundle that name makes codesign reject the bundle.
            resources: [.copy("UncleScam/Bundled")]
        ),
        .testTarget(
            name: "PrismetSharedTests",
            dependencies: ["PrismetShared"],
            // The answers prismet.xyz/scam gives; the Swift port must give the same, to the cent.
            resources: [.copy("Golden")]
        )
    ]
)
