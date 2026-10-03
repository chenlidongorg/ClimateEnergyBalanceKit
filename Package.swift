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
        .package(url: "https://github.com/chenlidongorg/AppShareKit.git", revision: "3a1ed5955dc0ad869dcf2aab1f8947028181644e")
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
