// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "multibuild",
    products: [
        .library(
            name: "Multibuild",
            targets: ["Multibuild"]),
    ],

    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],

    targets: [
        .target(
            name: "Multibuild",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            exclude: ["Environment"],
            resources: [
                .copy("Environment")
            ])
    ]
)
