import XCTest
@testable import ClimateEnergyBalanceKit

final class ClimateEnergyBalanceKitTests: XCTestCase {
    func testMetadataIsAvailable() {
        let metadata = ModuleInfo.metadata
        XCTAssertFalse(metadata.identifier.isEmpty)
        XCTAssertFalse(metadata.title.isEmpty)
        XCTAssertFalse(metadata.subtitle.isEmpty)
    }

    func testCo2ForcingRaisesEquilibriumTemperature() {
        let baseline = ClimateEnergySimulator.simulate(
            scenario: ClimatePreset.baseline.parameters,
            horizonDays: 365 * 4
        )
        let doubled = ClimateEnergySimulator.simulate(
            scenario: ClimatePreset.co2Doubled.parameters,
            horizonDays: 365 * 4
        )

        XCTAssertGreaterThan(
            doubled.metrics.equilibriumTemperature,
            baseline.metrics.equilibriumTemperature
        )
    }

    func testHigherAlbedoLowersNetForcing() {
        let baselineForcing = ClimateEnergySimulator.totalForcing(ClimatePreset.baseline.parameters)
        let highAlbedoForcing = ClimateEnergySimulator.totalForcing(ClimatePreset.higherAlbedo.parameters)
        XCTAssertLessThan(highAlbedoForcing, baselineForcing)
    }

    func testLargerHeatCapacityIncreasesTimeConstant() {
        let baseline = ClimateEnergySimulator.simulate(
            scenario: ClimatePreset.baseline.parameters,
            horizonDays: 365 * 2
        )
        let largerCapacity = ClimateEnergySimulator.simulate(
            scenario: ClimatePreset.largerHeatCapacity.parameters,
            horizonDays: 365 * 2
        )

        XCTAssertGreaterThan(
            largerCapacity.metrics.timeConstantYears,
            baseline.metrics.timeConstantYears
        )
    }
}
