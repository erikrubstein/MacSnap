// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacSnap",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.2")
    ],
    targets: [
        .target(
            name: "MacSnapCore"
        ),
        .executableTarget(
            name: "MacSnap",
            dependencies: [
                "MacSnapCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MacSnapCoreTests",
            dependencies: ["MacSnapCore"]
        )
    ]
)
