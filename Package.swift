// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AmazonCreatorsAPI",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "AmazonCreatorsAPI",
            targets: ["AmazonCreatorsAPI"]
        )
    ],
    targets: [
        .target(
            name: "AmazonCreatorsAPI"
        ),
        .testTarget(
            name: "AmazonCreatorsAPITests",
            dependencies: ["AmazonCreatorsAPI"]
        )
    ]
)
