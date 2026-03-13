import Foundation
import Combine

@MainActor
final class ClimateViewModel: ObservableObject {
    @Published var selectedPreset: ClimatePreset = .baseline
    @Published var solarMultiplier: Double = 1.0
    @Published var albedo: Double = 0.30
    @Published var co2Level: CO2Level = .x1
    @Published var heatCapacity: HeatCapacityLevel = .medium
    @Published var feedbackMode: FeedbackMode = .standard

    @Published var isRunning = false
    @Published var isParameterSheetPresented = false
    @Published private(set) var visibleDays: Int = 0
    @Published private(set) var simulation: ClimateSimulationResult = .empty

    private let runStep: Int = 8
    private let runIntervalNanoseconds: UInt64 = 90_000_000
    private var runTask: Task<Void, Never>?
    private var eventHandler: ((ModuleEvent) -> Void)?

    init() {
        applyPreset(.baseline, emitEvent: false)
        recompute(emitResetEvent: false)
    }

    deinit {
        runTask?.cancel()
    }

    var maxDays: Int {
        simulation.points.last?.day ?? 0
    }

    var visiblePoints: [ClimateSeriesPoint] {
        guard !simulation.points.isEmpty else { return [] }
        let end = min(max(0, visibleDays), maxDays)
        return Array(simulation.points.prefix(end + 1))
    }

    var currentPoint: ClimateSeriesPoint? {
        visiblePoints.last
    }

    var equilibriumText: String {
        String(format: "%.2f°C", simulation.metrics.equilibriumTemperature)
    }

    var timeConstantText: String {
        String(format: "%.1f y", simulation.metrics.timeConstantYears)
    }

    var netForcingText: String {
        String(format: "%.2f W/m²", simulation.metrics.netForcing)
    }

    var absorbedText: String {
        String(format: "%.1f W/m²", simulation.metrics.absorbedShortwave)
    }

    var outgoingText: String {
        String(format: "%.1f W/m²", simulation.metrics.outgoingLongwave)
    }

    var co2ForcingText: String {
        String(format: "%.2f W/m²", simulation.metrics.co2Forcing)
    }

    var dayText: String {
        "\(visibleDays)"
    }

    var currentScenarioTempText: String {
        guard let point = currentPoint else { return "--" }
        return String(format: "%.2f°C", point.scenarioTemp)
    }

    var solarText: String {
        String(format: "%.3f×", solarMultiplier)
    }

    var albedoText: String {
        String(format: "%.2f", albedo)
    }

    var explanationText: String {
        selectedPreset.localizedDescription
    }

    func bindEventHandler(_ onEvent: ((ModuleEvent) -> Void)?) {
        eventHandler = onEvent
    }

    func appear() {
        emit(.lifecycle(.appeared))
    }

    func disappear() {
        stopRunLoop()
        emit(.lifecycle(.disappeared))
    }

    func configureController(_ controller: ModuleController?) {
        controller?.onReset = { [weak self] in
            Task { @MainActor in
                self?.reset()
            }
        }
        controller?.onPause = { [weak self] in
            Task { @MainActor in
                self?.pause()
            }
        }
        controller?.onResume = { [weak self] in
            Task { @MainActor in
                self?.resume()
            }
        }
        controller?.onApplyPreset = { [weak self] rawName in
            Task { @MainActor in
                guard let self else { return }
                if let preset = ClimatePreset(rawValue: rawName) {
                    self.setPreset(preset)
                } else {
                    self.emit(
                        .custom(
                            name: "unsupported_command",
                            payload: ["command": "applyPreset", "value": rawName]
                        )
                    )
                }
            }
        }
        controller?.onSetParameter = { [weak self] key, value in
            Task { @MainActor in
                self?.setParameter(key: key, value: value)
            }
        }
    }

    func setPreset(_ preset: ClimatePreset) {
        applyPreset(preset, emitEvent: true)
        recompute(emitResetEvent: false)
    }

    func setSolarMultiplier(_ value: Double) {
        solarMultiplier = min(max(value, 0.94), 1.06)
        emit(.interaction(.parameterChanged(key: "solarMultiplier", value: solarText)))
        recompute(emitResetEvent: false)
    }

    func setAlbedo(_ value: Double) {
        albedo = min(max(value, 0.15), 0.45)
        emit(.interaction(.parameterChanged(key: "albedo", value: albedoText)))
        recompute(emitResetEvent: false)
    }

    func setCO2Level(_ value: CO2Level) {
        co2Level = value
        emit(.interaction(.parameterChanged(key: "co2Level", value: value.rawValue.description)))
        recompute(emitResetEvent: false)
    }

    func setHeatCapacity(_ value: HeatCapacityLevel) {
        heatCapacity = value
        emit(.interaction(.parameterChanged(key: "heatCapacity", value: value.rawValue)))
        recompute(emitResetEvent: false)
    }

    func setFeedbackMode(_ value: FeedbackMode) {
        feedbackMode = value
        emit(.interaction(.parameterChanged(key: "feedbackMode", value: value.rawValue)))
        recompute(emitResetEvent: false)
    }

    func setParameter(key: String, value: Double) {
        switch key.lowercased() {
        case "solar", "solarmultiplier":
            setSolarMultiplier(value)
        case "albedo":
            setAlbedo(value)
        case "co2", "co2level":
            if value < 1.5 {
                setCO2Level(.x1)
            } else if value < 3.0 {
                setCO2Level(.x2)
            } else {
                setCO2Level(.x4)
            }
        default:
            emit(.custom(name: "unsupported_command", payload: ["command": "setParameter", "key": key]))
        }
    }

    func toggleAutoRun() {
        isRunning ? pause() : resume()
    }

    func resume() {
        guard !isRunning else { return }
        isRunning = true
        emit(.business(.experimentStarted))
        startRunLoop()
    }

    func pause() {
        guard isRunning else { return }
        isRunning = false
        stopRunLoop()
        emit(.business(.experimentCompleted))
    }

    func reset() {
        stopRunLoop()
        isRunning = false
        visibleDays = 0
        emit(.business(.experimentReset))
    }

    func emitCaptureTapped() {
        emit(.interaction(.captureTapped))
    }

    func captureSnapshot() -> ClimateCaptureSnapshot {
        let sampled = downsample(visiblePoints, to: 220)
        return ClimateCaptureSnapshot(
            title: LocalizedInfo.Title,
            subtitle: LocalizedInfo.Subtitle,
            presetName: selectedPreset.localizedName,
            solarMultiplier: solarMultiplier,
            albedo: albedo,
            co2Name: co2Level.localizedName,
            heatCapacityName: heatCapacity.localizedName,
            feedbackName: feedbackMode.localizedName,
            equilibriumTemperature: simulation.metrics.equilibriumTemperature,
            timeConstantYears: simulation.metrics.timeConstantYears,
            scenarioSeries: sampled.map(\.scenarioTemp),
            baselineSeries: sampled.map(\.baselineTemp)
        )
    }

    private func applyPreset(_ preset: ClimatePreset, emitEvent: Bool) {
        selectedPreset = preset
        let parameters = preset.parameters
        solarMultiplier = parameters.solarMultiplier
        albedo = parameters.albedo
        co2Level = parameters.co2Level
        heatCapacity = parameters.heatCapacity
        feedbackMode = parameters.feedbackMode

        if emitEvent {
            emit(.interaction(.presetChanged(name: preset.rawValue)))
        }
    }

    private func recompute(emitResetEvent: Bool) {
        stopRunLoop()
        isRunning = false
        let scenario = ClimateParameters(
            solarMultiplier: solarMultiplier,
            albedo: albedo,
            co2Level: co2Level,
            heatCapacity: heatCapacity,
            feedbackMode: feedbackMode
        )
        simulation = ClimateEnergySimulator.simulate(scenario: scenario)
        visibleDays = 0
        if emitResetEvent {
            emit(.business(.experimentReset))
        }
    }

    private func startRunLoop() {
        stopRunLoop()
        runTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.isRunning {
                try? await Task.sleep(nanoseconds: self.runIntervalNanoseconds)
                guard self.isRunning else { break }
                self.advance()
            }
        }
    }

    private func stopRunLoop() {
        runTask?.cancel()
        runTask = nil
    }

    private func advance() {
        let next = min(maxDays, visibleDays + runStep)
        visibleDays = next
        if visibleDays >= maxDays {
            pause()
        }
    }

    private func downsample(_ values: [ClimateSeriesPoint], to target: Int) -> [ClimateSeriesPoint] {
        guard values.count > target, target > 1 else { return values }
        let stride = Double(values.count - 1) / Double(target - 1)
        return (0 ..< target).compactMap { point in
            let index = Int((Double(point) * stride).rounded())
            guard values.indices.contains(index) else { return nil }
            return values[index]
        }
    }

    private func emit(_ event: ModuleEvent) {
        eventHandler?(event)
    }
}
