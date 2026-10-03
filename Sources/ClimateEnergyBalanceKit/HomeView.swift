import SwiftUI
import UIKit
import ScienceLabUI

@MainActor
public struct HomeView: View {
    private let headerStyle: HeaderStyle
    private let qrcode: UIImage?
    private let onCapture: ((UIImage) -> Void)?
    private let onEvent: ((ModuleEvent) -> Void)?
    private let controller: ModuleController?
    @StateObject private var viewModel = ClimateViewModel()
    @State private var isCaptureConfirmed = false
    @State private var captureFeedbackTask: Task<Void,Never>?
    @State private var advanced = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    public init(headerStyle: HeaderStyle = .full, qrcode: UIImage? = nil, onCapture: ((UIImage)->Void)? = nil, onEvent: ((ModuleEvent)->Void)? = nil, controller: ModuleController? = nil) {
        self.headerStyle=headerStyle;self.qrcode=qrcode;self.onCapture=onCapture;self.onEvent=onEvent;self.controller=controller
    }
    public var body: some View {
        ScienceLabShell(title:LocalizedInfo.Title,subtitle:viewModel.text("science.scope"),showsTitle:headerStyle != .hidden,
            isRunning:viewModel.isRunning,isCaptureConfirmed:isCaptureConfirmed,stageInteractionPolicy:.bounded2D,
            labels:ScienceLabLabels(),initialReadoutMode:.minimized,onToggleRun:viewModel.toggleAutoRun,onReset:viewModel.reset,onCapture:handleCapture,onParameters:{advanced=true},
            stage:{_ in ClimateStageContent(model:viewModel,colorScheme:colorScheme)},controls:{regular},readouts:{readouts},knowledge:{
                ForEach(["science.model","science.units","science.coefficient","science.colors","science.endpoint","science.interaction"],id:\.self) {key in Text(viewModel.text(key)).fixedSize(horizontal:false,vertical:true)}
            })
        .sheet(isPresented:$advanced) {ScienceLabSheet(title:ScienceLabLabels().advancedParameters,doneLabel:ScienceLabLabels().done,prefersLarge:false,identifier:"scienceLab.advancedParameters.sheet") {advancedParameters}}
        .onAppear {viewModel.bindEventHandler(onEvent);viewModel.configureController(controller);viewModel.appear();viewModel.setSceneActive(scenePhase == .active)}
        .onChange(of:scenePhase) {viewModel.setSceneActive($0 == .active)}
        .onDisappear {captureFeedbackTask?.cancel();captureFeedbackTask=nil;isCaptureConfirmed=false;viewModel.disappear()}
    }
    private var regular: some View {
        VStack(alignment:.leading,spacing:16) {
            Picker(viewModel.text("section.preset"),selection:Binding(get:{viewModel.selectedPreset},set:{viewModel.setPreset($0)})) {
                ForEach(ClimatePreset.allCases) {Text($0.localizedName).tag($0)}
            }.pickerStyle(.menu)
            Text(viewModel.explanationText).font(.footnote).foregroundStyle(.secondary)
            slider("parameter.solar",viewModel.solarText,.init(get:{viewModel.solarMultiplier},set:{viewModel.setSolarMultiplier($0)}),0.94...1.06)
            slider("parameter.albedo",viewModel.albedoText,.init(get:{viewModel.albedo},set:{viewModel.setAlbedo($0)}),0.15...0.45)
            Picker(viewModel.text("parameter.co2"),selection:Binding(get:{viewModel.co2Level},set:{viewModel.setCO2Level($0)})) {ForEach(CO2Level.allCases) {Text($0.localizedName).tag($0)}}.pickerStyle(.segmented)
            Text(viewModel.text("science.scope")).font(.footnote).foregroundStyle(.secondary)
        }
    }
    private var advancedParameters: some View {
        VStack(alignment:.leading,spacing:16) {
            Text(viewModel.text("parameter.heatCapacity"))
            Picker(viewModel.text("parameter.heatCapacity"),selection:Binding(get:{viewModel.heatCapacity},set:{viewModel.setHeatCapacity($0)})) {ForEach(HeatCapacityLevel.allCases) {Text($0.localizedName).tag($0)}}.pickerStyle(.segmented)
            Text(viewModel.text("science.restoring"))
            Picker(viewModel.text("science.restoring"),selection:Binding(get:{viewModel.feedbackMode},set:{viewModel.setFeedbackMode($0)})) {ForEach(FeedbackMode.allCases) {Text($0.localizedName).tag($0)}}.pickerStyle(.segmented)
            Text(viewModel.text("science.units")).font(.footnote).foregroundStyle(.secondary)
            Text(viewModel.text("science.coefficient")).font(.footnote).foregroundStyle(.secondary)
            Button(viewModel.text("science.clearProbe")) {viewModel.clearProbe()}.buttonStyle(.bordered)
        }
    }
    private var readouts: some View {
        LazyVStack(alignment:.leading,spacing:8) {
            ForEach(Array(viewModel.scientificTexts.dropFirst().enumerated()),id:\.offset) {index,value in
                Text(value).font(.footnote.monospacedDigit()).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("climate.result.\(index)")
            }
            ForEach(viewModel.simulation.points) {p in
                Text(String(format:"%d,%.12g,%.12g",p.day,p.baselineTemp,p.scenarioTemp)).font(.footnote.monospacedDigit()).accessibilityIdentifier("climate.day.\(p.day)")
            }
        }
    }
    private func slider(_ key:String,_ value:String,_ binding:Binding<Double>,_ range:ClosedRange<Double>)->some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {Text(viewModel.text(key));Spacer();Text(value).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)}
            Slider(value:binding,in:range).accessibilityIdentifier("climate.parameter.\(key)")
        }
    }
    private func handleCapture() {
        guard !isCaptureConfirmed else{return};isCaptureConfirmed=true
        viewModel.deliverCapture(qrcode:qrcode,style:colorScheme == .dark ? .dark:.light,onCapture:onCapture,fallback:{_ = ScienceLabExportPresenter.present(image:$0,title:LocalizedInfo.Title)})
        captureFeedbackTask=Task { @MainActor in
            do {try await Task.sleep(nanoseconds:1_000_000_000)} catch {return}
            guard !Task.isCancelled else{return};isCaptureConfirmed=false;captureFeedbackTask=nil
        }
    }
}
