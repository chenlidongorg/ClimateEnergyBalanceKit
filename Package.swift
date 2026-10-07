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
        .package(url: "https://github.com/chenlidongorg/AppShareKit.git", revision: "0235bd1319d3908e90cec2f7fc66f87adb2075c2")
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
