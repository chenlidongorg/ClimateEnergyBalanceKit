import Foundation

/// Linear global-mean anomaly model, not an absolute-temperature climate forecast.
/// C is expressed in W year m^-2 K^-1; one model year is exactly 365 days.
enum ClimateEnergySimulator {
    static let secondsPerModelYear = 365.0 * 24 * 3600
    static let meanIncomingSolar = 340.0
    static let baselineAbsorbed = 238.0
    static let doublingForcing = 3.7 // Original rounded teaching coefficient, not AR6 ERF.
    static let defaultHorizonDays = 365 * 8

    static func normalized(_ value: ClimateParameters) -> ClimateParameters {
        var p = value
        p.solarMultiplier = p.solarMultiplier.isFinite ? min(max(p.solarMultiplier, 0), 4) : 1
        p.albedo = p.albedo.isFinite ? min(max(p.albedo, 0), 1) : 0.3
        return p
    }

    static func simulate(scenario: ClimateParameters, horizonDays: Int = defaultHorizonDays) -> ClimateSimulationResult {
        let p = normalized(scenario)
        // Bounded internal allocation; the shipped finite teaching record remains 8 years.
        let last = min(max(0, horizonDays), 365 * 200)
        let forcing = totalForcing(p), lambda = p.feedbackMode.lambda, c = p.heatCapacity.value
        let points = (0...last).map { day in
            ClimateSeriesPoint(day: day, baselineTemp: 0,
                scenarioTemp: forcing / lambda * -expm1(-lambda * Double(day) / (365 * c)))
        }
        // Summary metrics refer to the terminal forecast. Live readouts compute their own day.
        return .init(points: points, metrics: metrics(parameters: p, temperature: points.last!.scenarioTemp))
    }

    static func metrics(parameters: ClimateParameters, temperature: Double) -> ClimateMetrics {
        let p = normalized(parameters), t = temperature.isFinite ? temperature : 0
        let co2 = doublingForcing * log2(p.co2Level.rawValue)
        let absorbed = baselineAbsorbed + solarForcing(p)
        return .init(absorbedShortwave: absorbed,
            outgoingLongwave: baselineAbsorbed - co2 + p.feedbackMode.lambda * t,
            netForcing: solarForcing(p) + co2, co2Forcing: co2,
            equilibriumTemperature: (solarForcing(p) + co2) / p.feedbackMode.lambda,
            timeConstantYears: p.heatCapacity.value / p.feedbackMode.lambda)
    }

    static func totalForcing(_ parameters: ClimateParameters) -> Double {
        let p = normalized(parameters)
        return solarForcing(p) + doublingForcing * log2(p.co2Level.rawValue)
    }

    /// Algebraically identical to 340 m(1−a)−238, with exact reference cancellation.
    private static func solarForcing(_ p: ClimateParameters) -> Double {
        meanIncomingSolar * ((p.solarMultiplier - 1) * (1 - p.albedo) + (0.3 - p.albedo))
    }

    static func heatContent(parameters: ClimateParameters, temperature: Double) -> Double {
        parameters.heatCapacity.value * secondsPerModelYear * temperature
    }
}
