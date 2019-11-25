// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TezosGen",
    products: [
        .executable(name: "tezosgen", targets: ["tezosgen"])
    ],
    dependencies: [
        .package(url: "https://github.com/fortmarek/tuist.git", .branch("master")),
        .package(url: "https://github.com/fortmarek/acho", .branch("master"))
    ],
    targets: [
        .target(
            name: "tezosgen",
            dependencies: [
                "TezosGenKit",
            ]),
        .target(
            name: "TezosGenCore",
            dependencies: [
                "TuistGenerator",
                "acho",
            ]),
        .target(
            name: "TezosGenGenerator",
            dependencies: [
                "TezosGenCore"
            ]),
        .target(
            name: "TezosGenKit",
            dependencies: [
                "TezosGenCore",
                "TezosGenGenerator",
            ]),
        .target(
            name: "TezosGenCoreTesting",
            dependencies: [
                "TezosGenCore",
            ]),
        .testTarget(
            name: "TezosGenKitTests",
            dependencies: [
                "TezosGenKit",
                "TezosGenCoreTesting"
            ]),
        .testTarget(
            name: "TezosGenGeneratorTests",
            dependencies: [
                "TezosGenGenerator",
                "TezosGenCoreTesting"
            ]),
    ]
)
