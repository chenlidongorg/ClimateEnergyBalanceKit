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
    targets: [
        .target(
            name: "ClimateEnergyBalanceKit",
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
