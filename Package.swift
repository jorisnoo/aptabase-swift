// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Aptabase",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "Aptabase",
            targets: ["Aptabase"]),
    ],
    targets: [
        .target(
            name: "Aptabase",
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ]),
        .testTarget(
            name: "AptabaseTests",
            dependencies: ["Aptabase"]
        )
    ]
)
