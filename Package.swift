// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TezosGen",
    products: [
        .library(name: "TezosGen", targets: ["TezosGenFramework"]),
        .executable(name: "tezosgen", targets: ["tezosgen"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/jakeheis/SwiftCLI", .upToNextMajor(from: "5.2.0")),
        .package(url: "https://github.com/kylef/PathKit.git", .upToNextMajor(from: "0.9.1")),
        .package(url: "https://github.com/SwiftGen/StencilSwiftKit", .upToNextMajor(from: "2.6.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "TezosGenFramework",
            dependencies: [
                "PathKit",
                "StencilSwiftKit",
            ]),
        .target(
            name: "tezosgen",
            dependencies: [
                "SwiftCLI",
                .target(name: "TezosGenFramework")
            ]),
        .testTarget(
            name: "CLICodegenTests",
            dependencies: [
                .target(name: "TezosGenFramework"),
                "SwiftCLI",
                "PathKit",
            ]),
    ]
)
