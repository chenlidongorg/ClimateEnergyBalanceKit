import SwiftUI
import UIKit

public struct HomeView: View {
    private let headerStyle: HeaderStyle
    private let qrcode: UIImage?
    private let onCapture: ((UIImage) -> Void)?
    private let onEvent: ((ModuleEvent) -> Void)?
    private let controller: ModuleController?

    @StateObject private var viewModel = ClimateViewModel()
    @State private var isCaptureConfirmed = false
    @State private var captureFeedbackTask: Task<Void, Never>?

    public init(
        headerStyle: HeaderStyle = .full,
        qrcode: UIImage? = nil,
        onCapture: ((UIImage) -> Void)? = nil,
        onEvent: ((ModuleEvent) -> Void)? = nil,
        controller: ModuleController? = nil
    ) {
        self.headerStyle = headerStyle
        self.qrcode = qrcode
        self.onCapture = onCapture
        self.onEvent = onEvent
        self.controller = controller
    }

    public var body: some View {
        VStack(spacing: 0) {
            ClimateHeaderView(style: headerStyle, qrcode: qrcode)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    presetCard
                    quickParameterCard
                    energyFlowCard
                    curveCard
                    metricsCard
                    explanationCard
                }
                .padding(16)
            }

            ControlBarView(
                isRunning: viewModel.isRunning,
                isCaptureConfirmed: isCaptureConfirmed,
                onCapture: {
                    handleCapture()
                },
                onToggleRun: {
                    viewModel.toggleAutoRun()
                },
                onReset: {
                    viewModel.reset()
                }
            )
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $viewModel.isParameterSheetPresented) {
            parameterSheetPresentation
        }
        .onAppear {
            viewModel.bindEventHandler(onEvent)
            viewModel.configureController(controller)
            viewModel.appear()
        }
        .onDisappear {
            captureFeedbackTask?.cancel()
            captureFeedbackTask = nil
            isCaptureConfirmed = false
            viewModel.disappear()
        }
    }

    private var presetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedInfo.localized("section.preset"))
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.isParameterSheetPresented = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 42, height: 42)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LocalizedInfo.localized("action.parameters"))
            }

            Picker(
                LocalizedInfo.localized("section.preset"),
                selection: Binding(
                    get: { viewModel.selectedPreset },
                    set: { viewModel.setPreset($0) }
                )
            ) {
                ForEach(ClimatePreset.allCases) { preset in
                    Text(preset.localizedName).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var quickParameterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(LocalizedInfo.localized("section.quickParameters"))
                .font(.headline)

            sliderRow(
                title: LocalizedInfo.localized("parameter.solar"),
                valueText: viewModel.solarText,
                value: Binding(
                    get: { viewModel.solarMultiplier },
                    set: { viewModel.setSolarMultiplier($0) }
                ),
                range: 0.94 ... 1.06
            )

            sliderRow(
                title: LocalizedInfo.localized("parameter.albedo"),
                valueText: viewModel.albedoText,
                value: Binding(
                    get: { viewModel.albedo },
                    set: { viewModel.setAlbedo($0) }
                ),
                range: 0.15 ... 0.45
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(LocalizedInfo.localized("parameter.co2"))
                    Spacer()
                    Text(viewModel.co2Level.localizedName)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
                Picker(
                    LocalizedInfo.localized("parameter.co2"),
                    selection: Binding(
                        get: { viewModel.co2Level },
                        set: { viewModel.setCO2Level($0) }
                    )
                ) {
                    ForEach(CO2Level.allCases) { level in
                        Text(level.localizedName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var energyFlowCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedInfo.localized("section.energyFlow"))
                .font(.headline)

            EnergyFlowView(
                absorbed: viewModel.simulation.metrics.absorbedShortwave,
                outgoing: viewModel.simulation.metrics.outgoingLongwave,
                netForcing: viewModel.simulation.metrics.netForcing
            )
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var curveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedInfo.localized("section.curve"))
                .font(.headline)

            TemperatureLineChartView(points: viewModel.visiblePoints)

            HStack {
                Text("\(LocalizedInfo.localized("metric.day")): \(viewModel.dayText)")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(LocalizedInfo.localized("metric.netForcing")): \(viewModel.netForcingText)")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedInfo.localized("section.metrics"))
                .font(.headline)

            metricRow(LocalizedInfo.localized("metric.equilibrium"), viewModel.equilibriumText)
            metricRow(LocalizedInfo.localized("metric.timeConstant"), viewModel.timeConstantText)
            metricRow(LocalizedInfo.localized("metric.currentScenarioTemp"), viewModel.currentScenarioTempText)
            metricRow(LocalizedInfo.localized("metric.absorbed"), viewModel.absorbedText)
            metricRow(LocalizedInfo.localized("metric.outgoing"), viewModel.outgoingText)
            metricRow(LocalizedInfo.localized("metric.co2Forcing"), viewModel.co2ForcingText)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedInfo.localized("section.explanation"))
                .font(.headline)
            Text(viewModel.explanationText)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sliderRow(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
        }
    }

    private var parameterSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(LocalizedInfo.localized("section.parameters"))
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedInfo.localized("parameter.heatCapacity"))
                Picker(
                    LocalizedInfo.localized("parameter.heatCapacity"),
                    selection: Binding(
                        get: { viewModel.heatCapacity },
                        set: { viewModel.setHeatCapacity($0) }
                    )
                ) {
                    ForEach(HeatCapacityLevel.allCases) { level in
                        Text(level.localizedName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedInfo.localized("parameter.feedback"))
                Picker(
                    LocalizedInfo.localized("parameter.feedback"),
                    selection: Binding(
                        get: { viewModel.feedbackMode },
                        set: { viewModel.setFeedbackMode($0) }
                    )
                ) {
                    ForEach(FeedbackMode.allCases) { level in
                        Text(level.localizedName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            Button {
                viewModel.isParameterSheetPresented = false
            } label: {
                Text(LocalizedInfo.localized("action.done"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var parameterSheetPresentation: some View {
        if #available(iOS 16.0, *) {
            parameterSheet
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
        } else {
            parameterSheet
        }
    }

    private func handleCapture() {
        viewModel.emitCaptureTapped()
        let snapshot = viewModel.captureSnapshot()
        let image = CaptureImageRenderer.render(snapshot: snapshot, qrcode: qrcode)
        onCapture?(image)
        showCaptureFeedback()
    }

    private func showCaptureFeedback() {
        guard onCapture != nil else { return }
        captureFeedbackTask?.cancel()
        captureFeedbackTask = nil

        withAnimation(.easeOut(duration: 0.16)) {
            isCaptureConfirmed = true
        }

        captureFeedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation(.easeIn(duration: 0.2)) {
                isCaptureConfirmed = false
            }
            captureFeedbackTask = nil
        }
    }
}
