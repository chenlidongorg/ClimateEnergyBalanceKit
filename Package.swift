// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClimateEnergyBalanceKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "ClimateEnergyBalanceKit",
            targets: ["ClimateEnergyBalanceKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/chenlidongorg/AppShareKit.git", revision: "a8ee5da1c30027d0651d4e5e78b462bd2fa49c56")
    ],
    targets: [
        .target(
            name: "ClimateEnergyBalanceKit",
            dependencies: [.product(name: "ScienceLabUI", package: "AppShareKit")],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ClimateEnergyBalanceKitTests",
            dependencies: ["ClimateEnergyBalanceKit"]
        )
    ]
)
