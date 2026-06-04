// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GridSnap",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "GridSnapCore"
        ),
        .executableTarget(
            name: "GridSnap",
            dependencies: ["GridSnapCore"]
        ),
        .executableTarget(
            name: "GridSnapGeometryCheck",
            dependencies: ["GridSnapCore"],
            path: "Checks/GridSnapGeometryCheck"
        )
    ]
)
