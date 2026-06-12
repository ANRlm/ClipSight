// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ClipSight",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ClipSightCore",
            targets: ["ClipSightCore"]
        ),
        .executable(
            name: "ClipSight",
            targets: ["ClipSight"]
        )
    ],
    targets: [
        .target(
            name: "ClipSightCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ImageIO"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("Vision")
            ]
        ),
        .executableTarget(
            name: "ClipSight",
            dependencies: ["ClipSightCore"]
        ),
        .testTarget(
            name: "ClipSightCoreTests",
            dependencies: ["ClipSightCore"]
        )
    ]
)
