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
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0"),
    ],

    targets: [
        .target(
            name: "multibuild",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            resources: [
                .copy("Environment")
            ])
    ]
)
