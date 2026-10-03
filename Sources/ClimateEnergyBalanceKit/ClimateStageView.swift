import SwiftUI
import UIKit
import ScienceLabUI

struct ClimateStageContent: View {
    @ObservedObject var model:ClimateViewModel
    let colorScheme:ColorScheme
    @Environment(\.scienceLabStageInteraction) private var interaction
    var body:some View { ClimateObservedStage(model:model,colorScheme:colorScheme,interaction:interaction) }
}
private struct ClimateObservedStage: View {
    @ObservedObject var model:ClimateViewModel
    let colorScheme:ColorScheme
    @ObservedObject var interaction:ScienceLabStageInteraction
    @Environment(\.scenePhase) private var scenePhase
    @GestureState private var touching = false
    @State private var processed = false
    @State private var invalidated = false
    @State private var cancellationTask:Task<Void,Never>?
    var body:some View {
        GeometryReader { g in
            ClimateStageView(model:model,colorScheme:colorScheme)
                .contentShape(Rectangle()).coordinateSpace(name:"climate.stage.local")
                .gesture(DragGesture(minimumDistance:2,coordinateSpace:.named("climate.stage.local"))
                    .updating($touching) {_,state,_ in state = true}
                    .onChanged { value in
                        guard interaction.canReleaseObject,!invalidated else {invalidate();return}
                        if !processed {processed = true;invalidated = !model.beginProbe(at:value.startLocation,size:g.size)}
                        if !invalidated {model.updateProbe(at:value.location,size:g.size)}
                    }.onEnded {value in
                        cancellationTask?.cancel();cancellationTask = nil
                        if invalidated || !interaction.canReleaseObject {model.cancelProbe()} else {model.endProbe(at:value.location,size:g.size)}
                        processed = false;invalidated = false
                    })
                .onReceive(interaction.$cancellationGeneration.dropFirst()) {_ in invalidate()}
                .onChange(of:g.size) {_ in invalidate()}
                .onChange(of:scenePhase) {if $0 != .active {invalidate()}}
                .onChange(of:touching) {active in
                    cancellationTask?.cancel();cancellationTask = nil
                    if !active {let generation = model.probeGeneration;cancellationTask = Task { @MainActor in
                        await Task.yield();guard !Task.isCancelled,!touching else {return};model.cancelProbe(expectedGeneration:generation);processed = false;invalidated = false
                    }}
                }.onDisappear {cancellationTask?.cancel();cancellationTask = nil}
        }
    }
    private func invalidate() {model.cancelProbe();if processed {invalidated = true}}
}
struct ClimateStageView:UIViewRepresentable {
    @ObservedObject var model:ClimateViewModel
    let colorScheme:ColorScheme
    func makeUIView(context:Context)->ClimateDrawingView {let view = ClimateDrawingView();configure(view);return view}
    func updateUIView(_ view:ClimateDrawingView,context:Context) {configure(view)}
    private func configure(_ view:ClimateDrawingView) {
        model.connect(view);view.snapshotModel = model.stageSnapshot;view.appearance = .init(userInterfaceStyle:colorScheme == .dark ? .dark:.light)
        view.onSizeChanged = {[weak model] in model?.resize($0)}
        view.takeRemovalCancellation = {[weak model] in guard let model else {return nil};let generation = model.probeGeneration;return {[weak model] in model?.cancelProbe(expectedGeneration:generation)}}
        view.setNeedsDisplay()
    }
    static func dismantleUIView(_ view:ClimateDrawingView,coordinator:()) {view.prepareForRemoval()}
}
@MainActor
final class ClimateDrawingView:UIView {
    var snapshotModel:ClimateStageSnapshot?
    var appearance = UITraitCollection(userInterfaceStyle:.light)
    var onSizeChanged:((CGSize)->Void)?
    var takeRemovalCancellation:(()->(()->Void)?)?
    private var ending = false
    private var previousSize = CGSize.zero
    override init(frame:CGRect) {super.init(frame:frame);isOpaque = true;isUserInteractionEnabled = false;accessibilityIdentifier = "climate.diagram"}
    required init?(coder:NSCoder) {fatalError("init(coder:) has not been implemented")}
    override func draw(_ rect:CGRect) {guard let cg = UIGraphicsGetCurrentContext(),let snapshotModel else {return};ClimateStageRenderer.draw(snapshot:snapshotModel,in:cg,size:bounds.size,trait:appearance)}
    override func layoutSubviews() {
        super.layoutSubviews();guard !ending,bounds.size != previousSize else {return};previousSize = bounds.size;let size = bounds.size
        DispatchQueue.main.async {[weak self] in guard let self,!self.ending,self.bounds.size == size else {return};self.onSizeChanged?(size)};setNeedsDisplay()
    }
    func snapshot(snapshot:ClimateStageSnapshot,trait:UITraitCollection)->UIImage? {
        guard !ending,bounds.width>0,bounds.height>0 else {return nil};snapshotModel = snapshot;appearance = trait;setNeedsDisplay();layer.displayIfNeeded()
        let f = UIGraphicsImageRendererFormat();f.scale = 1;f.opaque = true
        return UIGraphicsImageRenderer(size:bounds.size,format:f).image {layer.render(in:$0.cgContext)}
    }
    func prepareForRemoval() {
        guard !ending else {return};ending = true;let cancel = takeRemovalCancellation?();takeRemovalCancellation = nil;onSizeChanged = nil
        DispatchQueue.main.async {cancel?()}
    }
}
