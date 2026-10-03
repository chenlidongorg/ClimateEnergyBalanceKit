import Foundation
import Combine
import UIKit

@MainActor
final class ClimateViewModel: ObservableObject {
    @Published var selectedPreset: ClimatePreset = .baseline
    @Published var solarMultiplier = 1.0
    @Published var albedo = 0.30
    @Published var co2Level: CO2Level = .x1
    @Published var heatCapacity: HeatCapacityLevel = .medium
    @Published var feedbackMode: FeedbackMode = .standard
    @Published private(set) var isRunning = false
    @Published var isParameterSheetPresented = false
    @Published private(set) var visibleDays = 0
    @Published private(set) var probeDay: Int?
    @Published private(set) var simulation: ClimateSimulationResult = .empty
    let localeIdentifier: String
    private(set) var stageSize = CGSize(width: 360, height: 420)
    private(set) var probeGeneration = 0
    private var probeBefore: Int?
    private var probing = false
    private var playhead = 0.0
    private var completed = false
    private var sceneActive = true
    private var runTask: Task<Void, Never>?
    private var eventHandler: ((ModuleEvent) -> Void)?
    private weak var drawingView: ClimateDrawingView?
    static let presentationDaysPerSecond = 8.0 / 0.09

    init(localeIdentifier: String = LocalizedInfo.activeLocale) {
        self.localeIdentifier = localeIdentifier
        recompute()
    }
    deinit { runTask?.cancel() }
    func text(_ key: String) -> String { LocalizedInfo.localized(key, localeIdentifier: localeIdentifier) }
    var parameters: ClimateParameters { .init(solarMultiplier: solarMultiplier, albedo: albedo, co2Level: co2Level, heatCapacity: heatCapacity, feedbackMode: feedbackMode) }
    var maxDays: Int { simulation.points.last?.day ?? 0 }
    var visiblePoints: [ClimateSeriesPoint] { Array(simulation.points.prefix(visibleDays + 1)) }
    var currentPoint: ClimateSeriesPoint? { simulation.points.indices.contains(visibleDays) ? simulation.points[visibleDays] : nil }
    var observedDay: Int { min(max(0, probeDay ?? visibleDays), maxDays) }
    var observedPoint: ClimateSeriesPoint { simulation.points[observedDay] }
    var liveMetrics: ClimateMetrics { ClimateEnergySimulator.metrics(parameters: parameters, temperature: observedPoint.scenarioTemp) }
    var stageSnapshot: ClimateStageSnapshot { .init(points: simulation.points, visibleDay: visibleDays, probeDay: probeDay, localeIdentifier: localeIdentifier, parameters: parameters, isRunning: isRunning) }
    var equilibriumText: String { String(format: "%.9g K", liveMetrics.equilibriumTemperature) }
    var timeConstantText: String { String(format: "%.9g y", liveMetrics.timeConstantYears) }
    var netForcingText: String { String(format: "%.9g W/m²", liveMetrics.netForcing) }
    var absorbedText: String { String(format: "%.9g W/m²", liveMetrics.absorbedShortwave) }
    var outgoingText: String { String(format: "%.9g W/m²", liveMetrics.outgoingLongwave) }
    var co2ForcingText: String { String(format: "%.9g W/m²", liveMetrics.co2Forcing) }
    var dayText: String { String(visibleDays) }
    var currentScenarioTempText: String { String(format: "%.9g K", currentPoint?.scenarioTemp ?? 0) }
    var solarText: String { String(format: "%.3f×", solarMultiplier) }
    var albedoText: String { String(format: "%.3f", albedo) }
    var explanationText: String { selectedPreset == .largerHeatCapacity ? text("science.capacityPreset") : presetText("desc") }
    private func presetText(_ suffix: String) -> String {
        let stem: String
        switch selectedPreset { case .baseline: stem = "baseline"; case .co2Doubled: stem = "co2"; case .higherAlbedo: stem = "albedo"; case .largerHeatCapacity: stem = "capacity" }
        return text("preset.\(stem).\(suffix)")
    }
    var scientificTexts: [String] {
        let m = liveMetrics, t = observedPoint.scenarioTemp
        return [text("module.title"), text("science.scope"), text("science.model"), text("science.units"), text("science.coefficient"), text("science.colors"), text("science.endpoint"), text("science.interaction"), explanationText,
            "preset=\(selectedPreset.rawValue) (\(presetText("title"))); locale=\(localeIdentifier)",
            String(format: "S̄=340 W/m²; solarMultiplier=%.12g; albedo=%.12g; CO₂/C₀=%.12g", solarMultiplier, albedo, co2Level.rawValue),
            String(format: "C=%.12g W y/(m² K) = %.12g J/(m² K); λ=%.12g W/(m² K); heatCapacity=%@; feedbackMode=%@", heatCapacity.value, heatCapacity.value * ClimateEnergySimulator.secondsPerModelYear, feedbackMode.lambda, heatCapacity.rawValue, feedbackMode.rawValue),
            String(format: "F_solar=%.12g W/m²; F_CO₂=%.12g W/m²; F_total=%.12g W/m²", m.netForcing - m.co2Forcing, m.co2Forcing, m.netForcing),
            "\(text("science.status")): visibleDay=\(visibleDays)/\(maxDays); running=\(isRunning); complete=\(completed); probeDay=\(probeDay.map(String.init) ?? "none")",
            String(format: "\(text("science.observed")): day=%d; t=%.12g y; ΔT_baseline=0 K; ΔT_scenario=%.12g K", observedDay, Double(observedDay)/365, t),
            String(format: "ASR=%.12g W/m²; OLR=%.12g W/m²; N=ASR−OLR=%.12g W/m²", m.absorbedShortwave, m.outgoingLongwave, m.netImbalance),
            String(format: "ΔT_eq=%.12g K; τ=C/λ=%.12g y; dΔT/dt=%.12g K/y", m.equilibriumTemperature, m.timeConstantYears, m.netImbalance/heatCapacity.value),
            String(format: "ΔQ=C_SI ΔT=%.12g J/m²; Q_in−Q_out=ΔQ", ClimateEnergySimulator.heatContent(parameters: parameters, temperature: t)),
            String(format: "\(text("science.clock")): %.12g model days/presentation second; presentationPlayhead=%.12g d", Self.presentationDaysPerSecond, playhead),
            text("science.record") + " \(simulation.points.count)" ]
    }
    var pointTexts: [String] { simulation.points.map { String(format: "%d,%.12g,%.12g", $0.day, $0.baselineTemp, $0.scenarioTemp) } }

    func bindEventHandler(_ handler: ((ModuleEvent) -> Void)?) { eventHandler = handler }
    func appear() { emit(.lifecycle(.appeared)) }
    func disappear() { cancelProbe(); pause(); emit(.lifecycle(.disappeared)) }
    func setSceneActive(_ active: Bool) { sceneActive = active; if !active { cancelProbe(); pause() } }
    func configureController(_ controller: ModuleController?) {
        controller?.onReset = { [weak self] in Task { @MainActor in self?.reset() } }
        controller?.onPause = { [weak self] in Task { @MainActor in self?.pause() } }
        controller?.onResume = { [weak self] in Task { @MainActor in self?.resume() } }
        controller?.onApplyPreset = { [weak self] name in Task { @MainActor in
            guard let self else { return }; if let p = ClimatePreset(rawValue: name) { self.setPreset(p) }
            else { self.emit(.custom(name: "unsupported_command", payload: ["command": "applyPreset", "value": name])) }
        } }
        controller?.onSetParameter = { [weak self] key, value in Task { @MainActor in self?.setParameter(key: key, value: value) } }
    }
    func setPreset(_ p: ClimatePreset) {
        selectedPreset = p; let v = p.parameters
        solarMultiplier = v.solarMultiplier; albedo = v.albedo; co2Level = v.co2Level; heatCapacity = v.heatCapacity; feedbackMode = v.feedbackMode
        recompute(); emit(.interaction(.presetChanged(name: p.rawValue)))
    }
    func setSolarMultiplier(_ value: Double) { guard valid(value) else { return }; solarMultiplier = min(max(value, 0.94), 1.06); recompute(); changed("solarMultiplier", solarText) }
    func setAlbedo(_ value: Double) { guard valid(value) else { return }; albedo = min(max(value, 0.15), 0.45); recompute(); changed("albedo", albedoText) }
    func setCO2Level(_ value: CO2Level) { co2Level = value; recompute(); changed("co2Level", value.rawValue.description) }
    func setHeatCapacity(_ value: HeatCapacityLevel) { heatCapacity = value; recompute(); changed("heatCapacity", value.rawValue) }
    func setFeedbackMode(_ value: FeedbackMode) { feedbackMode = value; recompute(); changed("feedbackMode", value.rawValue) }
    func setParameter(key: String, value: Double) {
        guard valid(value) else { return }
        switch key.lowercased() {
        case "solar", "solarmultiplier": setSolarMultiplier(value)
        case "albedo": setAlbedo(value)
        case "co2", "co2level": setCO2Level(value < 1.5 ? .x1 : (value < 3 ? .x2 : .x4))
        default: emit(.custom(name: "unsupported_command", payload: ["command": "setParameter", "key": key]))
        }
    }
    private func valid(_ value: Double) -> Bool {
        guard value.isFinite else { emit(.error(code: "invalid_parameter", message: "Expected finite value")); return false }; return true
    }
    private func changed(_ key: String, _ value: String) { emit(.interaction(.parameterChanged(key: key, value: value))) }
    func toggleAutoRun() { isRunning ? pause() : resume() }
    func resume() {
        guard !isRunning, sceneActive, visibleDays < maxDays else { return }
        isRunning = true; emit(.business(.experimentStarted)); startRunLoop()
    }
    func pause() { let wasRunning = isRunning; isRunning = false; stopRunLoop(); if wasRunning { emit(.custom(name: "experiment_paused", payload: ["visibleDay": String(visibleDays)])) } }
    func reset() { pause(); cancelProbe(); playhead = 0; visibleDays = 0; completed = false; emit(.business(.experimentReset)) }
    func advance(activeSeconds: Double) {
        guard isRunning, sceneActive, activeSeconds.isFinite, activeSeconds > 0 else { return }
        playhead = min(Double(maxDays), playhead + min(activeSeconds, 0.25) * Self.presentationDaysPerSecond)
        visibleDays = min(maxDays, Int(floor(playhead)))
        if playhead >= Double(maxDays) { isRunning = false; stopRunLoop(); if !completed { completed = true; emit(.business(.experimentCompleted)) } }
    }
    private func recompute() { pause(); cancelProbe(); simulation = ClimateEnergySimulator.simulate(scenario: parameters); playhead = 0; visibleDays = 0; completed = false }
    private func startRunLoop() {
        stopRunLoop(); runTask = Task { @MainActor [weak self] in
            var previous = ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 30_000_000) } catch { return }
                let now = ProcessInfo.processInfo.systemUptime; let dt = now - previous; previous = now
                guard !Task.isCancelled, let model = self, model.isRunning else { return }; model.advance(activeSeconds: dt)
            }
        }
    }
    private func stopRunLoop() { runTask?.cancel(); runTask = nil }
    func beginProbe(at point: CGPoint, size: CGSize) -> Bool {
        let plot = ClimateStageRenderer.plot(in: size)
        guard point.x >= plot.minX, point.x <= plot.maxX,
              point.y >= plot.minY, point.y <= plot.maxY else { return false }
        cancelProbe(); probeGeneration += 1; probing = true; probeBefore = probeDay; updateProbe(at: point, size: size); return true
    }
    func updateProbe(at point: CGPoint, size: CGSize) {
        guard probing, point.x.isFinite else { return }; let plot = ClimateStageRenderer.plot(in: size)
        guard plot.width > 0 else { return }; let fraction = min(max((point.x - plot.minX)/plot.width, 0), 1)
        probeDay = min(visibleDays, Int((fraction * CGFloat(maxDays)).rounded()))
    }
    func endProbe(at point: CGPoint, size: CGSize) { guard probing else { return }; updateProbe(at: point, size: size); probing = false; probeBefore = nil }
    func cancelProbe(expectedGeneration: Int? = nil) {
        if let expectedGeneration, expectedGeneration != probeGeneration { return }
        if probing { probeDay = probeBefore }; probing = false; probeBefore = nil; probeGeneration += 1
    }
    func clearProbe() { cancelProbe(); probeDay = nil }
    func resize(_ size: CGSize) { let safe = CaptureImageRenderer.sanitizedSize(size); guard safe != stageSize else { return }; cancelProbe(); stageSize = safe }
    func connect(_ view: ClimateDrawingView) { drawingView = view }
    func emitCaptureTapped() { emit(.interaction(.captureTapped)) }
    func captureSnapshot() -> ClimateCaptureSnapshot {
        .init(title: text("module.title"), subtitle: text("science.scope"), presetName: presetText("title"), solarMultiplier: solarMultiplier, albedo: albedo,
            co2Name: co2Level.localizedName, heatCapacityName: heatCapacity.localizedName, feedbackName: feedbackMode.localizedName,
            equilibriumTemperature: liveMetrics.equilibriumTemperature, timeConstantYears: liveMetrics.timeConstantYears,
            scenarioSeries: simulation.points.map(\.scenarioTemp), baselineSeries: simulation.points.map(\.baselineTemp),
            stage: stageSnapshot, texts: scientificTexts, points: simulation.points)
    }
    func deliverCapture(qrcode: UIImage?, style: UIUserInterfaceStyle, onCapture: ((UIImage) -> Void)?, fallback: (UIImage) -> Void) {
        emitCaptureTapped(); let snapshot = captureSnapshot(); let trait = UITraitCollection(userInterfaceStyle: style)
        let actual = drawingView?.snapshot(snapshot: stageSnapshot, trait: trait)
        let image = CaptureImageRenderer.render(snapshot: snapshot, size: stageSize, qrcode: qrcode, userInterfaceStyle: style, stageImage: actual)
        if let onCapture { onCapture(image) } else { fallback(image) }
    }
    private func emit(_ event: ModuleEvent) { eventHandler?(event) }
}
