// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "multibuild",
    products: [
        .library(
            name: "multibuild",
            targets: ["multibuild"]),
    ],

    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0"),
    ],

    targets: [
        .target(
            name: "multibuild",
            dependencies: [],
            resources: [
                .copy("Environment")
            ]
        )
    ]
)
