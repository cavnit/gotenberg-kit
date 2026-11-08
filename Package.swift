// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "gotenberg-kit",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "GotenbergKit",
            targets: ["GotenbergKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
    ],
    targets: [
        .target(
            name: "GotenbergKit",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .testTarget(
            name: "GotenbergKitTests",
            dependencies: ["GotenbergKit"]
        ),
    ]
)
