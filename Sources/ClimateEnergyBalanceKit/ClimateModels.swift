import Foundation

enum CO2Level: Double, CaseIterable, Identifiable {
    case x1 = 1
    case x2 = 2
    case x4 = 4

    var id: Double { rawValue }

    var localizedName: String {
        switch self {
        case .x1:
            return LocalizedInfo.localized("co2.x1")
        case .x2:
            return LocalizedInfo.localized("co2.x2")
        case .x4:
            return LocalizedInfo.localized("co2.x4")
        }
    }
}

enum HeatCapacityLevel: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .low:
            return LocalizedInfo.localized("capacity.low")
        case .medium:
            return LocalizedInfo.localized("capacity.medium")
        case .high:
            return LocalizedInfo.localized("capacity.high")
        }
    }

    var value: Double {
        switch self {
        case .low:
            return 6.0
        case .medium:
            return 10.0
        case .high:
            return 18.0
        }
    }
}

enum FeedbackMode: String, CaseIterable, Identifiable {
    case weak
    case standard
    case strong

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .weak:
            return LocalizedInfo.localized("feedback.weak")
        case .standard:
            return LocalizedInfo.localized("feedback.standard")
        case .strong:
            return LocalizedInfo.localized("feedback.strong")
        }
    }

    var lambda: Double {
        switch self {
        case .weak:
            return 0.85
        case .standard:
            return 1.10
        case .strong:
            return 1.35
        }
    }
}

enum ClimatePreset: String, CaseIterable, Identifiable {
    case baseline
    case co2Doubled
    case higherAlbedo
    case largerHeatCapacity

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .baseline:
            return LocalizedInfo.localized("preset.baseline.title")
        case .co2Doubled:
            return LocalizedInfo.localized("preset.co2.title")
        case .higherAlbedo:
            return LocalizedInfo.localized("preset.albedo.title")
        case .largerHeatCapacity:
            return LocalizedInfo.localized("preset.capacity.title")
        }
    }

    var localizedDescription: String {
        switch self {
        case .baseline:
            return LocalizedInfo.localized("preset.baseline.desc")
        case .co2Doubled:
            return LocalizedInfo.localized("preset.co2.desc")
        case .higherAlbedo:
            return LocalizedInfo.localized("preset.albedo.desc")
        case .largerHeatCapacity:
            return LocalizedInfo.localized("preset.capacity.desc")
        }
    }

    var parameters: ClimateParameters {
        switch self {
        case .baseline:
            return ClimateParameters(
                solarMultiplier: 1.00,
                albedo: 0.30,
                co2Level: .x1,
                heatCapacity: .medium,
                feedbackMode: .standard
            )
        case .co2Doubled:
            return ClimateParameters(
                solarMultiplier: 1.00,
                albedo: 0.30,
                co2Level: .x2,
                heatCapacity: .medium,
                feedbackMode: .standard
            )
        case .higherAlbedo:
            return ClimateParameters(
                solarMultiplier: 1.00,
                albedo: 0.36,
                co2Level: .x1,
                heatCapacity: .medium,
                feedbackMode: .standard
            )
        case .largerHeatCapacity:
            return ClimateParameters(
                solarMultiplier: 1.00,
                albedo: 0.30,
                co2Level: .x2,
                heatCapacity: .high,
                feedbackMode: .standard
            )
        }
    }
}

struct ClimateParameters {
    var solarMultiplier: Double
    var albedo: Double
    var co2Level: CO2Level
    var heatCapacity: HeatCapacityLevel
    var feedbackMode: FeedbackMode
}

struct ClimateSeriesPoint: Identifiable {
    let day: Int
    let baselineTemp: Double
    let scenarioTemp: Double

    var id: Int { day }
}

struct ClimateMetrics {
    let absorbedShortwave: Double
    let outgoingLongwave: Double
    let netForcing: Double
    let co2Forcing: Double
    let equilibriumTemperature: Double
    let timeConstantYears: Double
}

struct ClimateSimulationResult {
    let points: [ClimateSeriesPoint]
    let metrics: ClimateMetrics

    static let empty = ClimateSimulationResult(
        points: [],
        metrics: ClimateMetrics(
            absorbedShortwave: 0,
            outgoingLongwave: 0,
            netForcing: 0,
            co2Forcing: 0,
            equilibriumTemperature: 0,
            timeConstantYears: 0
        )
    )
}

struct ClimateCaptureSnapshot {
    let title: String
    let subtitle: String
    let presetName: String
    let solarMultiplier: Double
    let albedo: Double
    let co2Name: String
    let heatCapacityName: String
    let feedbackName: String
    let equilibriumTemperature: Double
    let timeConstantYears: Double
    let scenarioSeries: [Double]
    let baselineSeries: [Double]
}
