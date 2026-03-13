import Foundation

enum ClimateEnergySimulator {
    private static let meanIncomingSolar = 340.0
    private static let baselineAlbedo = 0.30
    private static let baselineFeedbackLambda = 1.10
    private static let baselineHeatCapacity = 10.0
    private static let dtYears = 1.0 / 365.0

    static func simulate(
        scenario: ClimateParameters,
        horizonDays: Int = 365 * 8
    ) -> ClimateSimulationResult {
        let baseline = ClimateParameters(
            solarMultiplier: 1.0,
            albedo: baselineAlbedo,
            co2Level: .x1,
            heatCapacity: .medium,
            feedbackMode: .standard
        )

        let baselineSeries = integrateTemperature(parameters: baseline, horizonDays: horizonDays)
        let scenarioSeries = integrateTemperature(parameters: scenario, horizonDays: horizonDays)
        let metrics = computeMetrics(parameters: scenario, currentTemperature: scenarioSeries.last ?? 0)

        let points = (0 ... horizonDays).map { day in
            ClimateSeriesPoint(
                day: day,
                baselineTemp: baselineSeries[day],
                scenarioTemp: scenarioSeries[day]
            )
        }

        return ClimateSimulationResult(points: points, metrics: metrics)
    }

    private static func integrateTemperature(parameters: ClimateParameters, horizonDays: Int) -> [Double] {
        let forcing = totalForcing(parameters)
        let lambda = parameters.feedbackMode.lambda
        let capacity = parameters.heatCapacity.value

        var temperature = 0.0
        var series = Array(repeating: 0.0, count: horizonDays + 1)
        series[0] = 0

        if horizonDays == 0 {
            return series
        }

        for day in 1 ... horizonDays {
            let tendency = (forcing - lambda * temperature) / capacity
            temperature += tendency * dtYears
            series[day] = temperature
        }

        return series
    }

    private static func computeMetrics(parameters: ClimateParameters, currentTemperature: Double) -> ClimateMetrics {
        let absorbed = meanIncomingSolar * parameters.solarMultiplier * (1 - parameters.albedo)
        let forcing = totalForcing(parameters)
        let co2Forcing = forcingFromCO2(parameters.co2Level)
        let lambda = parameters.feedbackMode.lambda
        let outgoing = absorbed - forcing + lambda * currentTemperature
        let equilibrium = forcing / lambda
        let tau = parameters.heatCapacity.value / lambda

        return ClimateMetrics(
            absorbedShortwave: absorbed,
            outgoingLongwave: outgoing,
            netForcing: forcing,
            co2Forcing: co2Forcing,
            equilibriumTemperature: equilibrium,
            timeConstantYears: tau
        )
    }

    static func totalForcing(_ parameters: ClimateParameters) -> Double {
        forcingFromSolarAndAlbedo(parameters.solarMultiplier, parameters.albedo) + forcingFromCO2(parameters.co2Level)
    }

    private static func forcingFromSolarAndAlbedo(_ solarMultiplier: Double, _ albedo: Double) -> Double {
        let baselineAbsorbed = meanIncomingSolar * (1 - baselineAlbedo)
        let absorbed = meanIncomingSolar * solarMultiplier * (1 - albedo)
        return absorbed - baselineAbsorbed
    }

    private static func forcingFromCO2(_ co2Level: CO2Level) -> Double {
        guard co2Level.rawValue > 0 else { return 0 }
        return 3.7 * log2(co2Level.rawValue)
    }
}
