// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacSnap",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "MacSnapCore"
        ),
        .executableTarget(
            name: "MacSnap",
            dependencies: ["MacSnapCore"],
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
