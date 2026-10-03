import XCTest
import SwiftUI
import UIKit
import CoreImage
import QuartzCore
@testable import ClimateEnergyBalanceKit

@MainActor
private final class ClimateNativeHost: UIHostingController<AnyView> {
    private(set) var appeared = false
    private(set) var disappeared = false
    weak var previousKeyWindow: UIWindow?
    override func viewDidAppear(_ animated: Bool) {super.viewDidAppear(animated);appeared=true}
    override func viewDidDisappear(_ animated: Bool) {super.viewDidDisappear(animated);disappeared=true}
}
@MainActor
final class ClimateNativeTests: XCTestCase {
    private let qrPayload="https://example.org/science/climate?year=365&forcing=3.7"
    private func finish(_ m: ClimateViewModel) {m.setSceneActive(true);m.resume();for _ in 0..<132 {m.advance(activeSeconds:0.25)};XCTAssertEqual(m.visibleDays,2920);XCTAssertFalse(m.isRunning)}
    func testActualFourPresetsBothTraitsShareCorrectAxesAndExportByteIdenticalCompleteNativeStage() async throws {
        let size=CGSize(width:812,height:375)
        for dark in [false,true] {for preset in ClimatePreset.allCases {
            let m=ClimateViewModel();m.setPreset(preset);finish(m)
            let (window,host)=try await mount(AnyView(ClimateStageView(model:m,colorScheme:dark ? .dark:.light).ignoresSafeArea()),size:size,dark:dark)
            let settled=await wait {self.drawing(host.view)?.bounds.size==size && m.stageSize==size};XCTAssertTrue(settled)
            let view=try XCTUnwrap(drawing(host.view)),live=try XCTUnwrap(view.snapshot(snapshot:m.stageSnapshot,trait:.init(userInterfaceStyle:dark ? .dark:.light))),snap=m.captureSnapshot()
            XCTAssertGreaterThan(try coloredCount(live,rect:ClimateStageRenderer.plot(in:size),color:"blue"),80)
            var record:UIImage?;m.deliverCapture(qrcode:nil,style:dark ? .dark:.light,onCapture:{record=$0},fallback:{_ in XCTFail("Unexpected fallback")})
            let report=try XCTUnwrap(record),layout=CaptureImageRenderer.layout(snapshot:snap,size:size,hasQRCode:false)
            XCTAssertEqual(try pixels(UIImage(cgImage:try XCTUnwrap(report.cgImage?.cropping(to:layout.stage)))),try pixels(live))
            XCTAssertEqual(layout.texts.count,snap.texts.count+2921);XCTAssertTrue(layout.texts.allSatisfy {$0.rect.maxY<layout.canvas.height && $0.rect.maxX<=layout.canvas.width && $0.fontSize>=14})
            XCTAssertFalse(view.isUserInteractionEnabled);XCTAssertTrue((view.gestureRecognizers ?? []).isEmpty)
            attach(live,"Climate-actual-\(preset.rawValue)-\(dark ? "dark":"light")-complete-8year-native-stage")
            attach(report,"Climate-actual-\(preset.rawValue)-\(dark ? "dark":"light")-full-2921row-parameters-SI-energy-record")
            await unmount(window,host:host);m.disappear()
        }}
    }
    func testActualCurvePassesIndependentOneYearTemperaturePixelOnSameBaselineAxis() async throws {
        let m=ClimateViewModel();m.setPreset(.co2Doubled);finish(m);let size=CGSize(width:812,height:375)
        let (window,host)=try await mount(AnyView(ClimateStageView(model:m,colorScheme:.light).ignoresSafeArea()),size:size,dark:false)
        let ready=await wait {self.drawing(host.view)?.bounds.size==size};XCTAssertTrue(ready)
        let image=try XCTUnwrap(drawing(host.view)?.snapshot(snapshot:m.stageSnapshot,trait:.init(userInterfaceStyle:.light))),r=ClimateStageRenderer.plot(in:size)
        let terminal=3.7/1.1*(1-exp(-1.1*8/10)),pad=terminal*0.12,oneYear=3.7/1.1*(1-exp(-1.1/10))
        let point=CGPoint(x:r.minX+r.width/8,y:r.maxY-CGFloat((oneYear+pad)/(terminal+pad*2))*r.height)
        XCTAssertGreaterThan(try coloredCount(image,rect:.init(x:point.x-3,y:point.y-3,width:6,height:6),color:"blue"),8)
        attach(image,"Climate-actual-CO2doubled-independent-one-year-temperature-curve-pixel")
        await unmount(window,host:host);m.disappear()
    }
    func testActualSevenWindowShapesBothTraitsHaveSystemBackgroundAndVisibleCurveWithinCurrentBounds() async throws {
        for dark in [false,true] {for size in [CGSize(width:320,height:568),.init(width:568,height:320),.init(width:375,height:812),.init(width:812,height:375),.init(width:600,height:600),.init(width:390,height:390),.init(width:1024,height:768)] {
            let m=ClimateViewModel();m.setPreset(.higherAlbedo);finish(m)
            let (window,host)=try await mount(AnyView(ClimateStageView(model:m,colorScheme:dark ? .dark:.light).ignoresSafeArea()),size:size,dark:dark)
            let ready=await wait {self.drawing(host.view)?.bounds.size==size && m.stageSize==size};XCTAssertTrue(ready)
            let image=try XCTUnwrap(drawing(host.view)?.snapshot(snapshot:m.stageSnapshot,trait:.init(userInterfaceStyle:dark ? .dark:.light)))
            let pixel=try pixels(UIImage(cgImage:try XCTUnwrap(image.cgImage?.cropping(to:.init(x:5,y:5,width:2,height:2)))))
            for c in 0..<3 {XCTAssertEqual(Int(pixel[c]),dark ? 0:255,accuracy:2)}
            XCTAssertGreaterThan(try coloredCount(image,rect:ClimateStageRenderer.plot(in:size),color:"blue"),50)
            XCTAssertLessThan(ClimateStageRenderer.plot(in:size).maxY,size.height);attach(image,"Climate-actual-cooling-\(dark ? "dark":"light")-\(Int(size.width))x\(Int(size.height))-same-axis-native")
            await unmount(window,host:host);m.disappear()
        }}
    }
    func testActualFractionalViewportAndReportFillAllNativeRasterCorners() throws {
        let m=ClimateViewModel();m.setPreset(.co2Doubled);finish(m);let size=CGSize(width:375.5,height:667.25)
        for dark in [false,true] {
            let stage=CaptureImageRenderer.stage(snapshot:m.stageSnapshot,size:size,userInterfaceStyle:dark ? .dark:.light)
            let report=CaptureImageRenderer.render(snapshot:m.captureSnapshot(),size:size,userInterfaceStyle:dark ? .dark:.light,stageImage:stage)
            let cg=try XCTUnwrap(report.cgImage),pixel=try pixels(UIImage(cgImage:try XCTUnwrap(cg.cropping(to:.init(x:cg.width-2,y:cg.height-2,width:2,height:2)))))
            for c in 0..<3 {XCTAssertEqual(Int(pixel[c]),dark ? 0:255,accuracy:2)}
            let layout=CaptureImageRenderer.layout(snapshot:m.captureSnapshot(),size:size,hasQRCode:false)
            XCTAssertEqual(try pixels(UIImage(cgImage:try XCTUnwrap(cg.cropping(to:layout.stage)))),try pixels(stage));attach(report,"Climate-actual-fractional-\(dark ? "dark":"light")-whole-raster-full-record")
        };m.disappear()
    }
    func testActualCompleteENZH2921RowsReadableMeasuredAndCallerQRIsLastWithoutDataLoss() throws {
        let qr=try realQR()
        for dark in [false,true] {
            let m=ClimateViewModel(localeIdentifier:dark ? "zh-Hans":"en");m.setPreset(.largerHeatCapacity);m.resize(.init(width:375,height:812));finish(m)
            let snapshot=m.captureSnapshot(),layout=CaptureImageRenderer.layout(snapshot:snapshot,size:m.stageSize,hasQRCode:true)
            let report=CaptureImageRenderer.render(snapshot:snapshot,size:m.stageSize,qrcode:qr,userInterfaceStyle:dark ? .dark:.light)
            XCTAssertEqual(layout.texts.count,snapshot.texts.count+2921);XCTAssertEqual(layout.texts.last?.text,String(format:"2920,0,%.12g",snapshot.points.last!.scenarioTemp))
            for row in layout.texts {
                let measured=(row.text as NSString).boundingRect(with:.init(width:row.rect.width,height:.greatestFiniteMagnitude),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:CaptureImageRenderer.attributes(font:row.fontSize),context:nil)
                XCTAssertGreaterThanOrEqual(row.rect.height,ceil(measured.height));XCTAssertGreaterThanOrEqual(row.fontSize,14)
            }
            let png=try XCTUnwrap(report.pngData());XCTAssertEqual(Array(png.prefix(8)),[137,80,78,71,13,10,26,10])
            let footer=try XCTUnwrap(layout.qrcode);XCTAssertLessThan(layout.texts.last!.rect.maxY,footer.minY-16)
            let crop=try XCTUnwrap(report.cgImage?.cropping(to:footer)),detector=try XCTUnwrap(CIDetector(ofType:CIDetectorTypeQRCode,context:nil,options:[CIDetectorAccuracy:CIDetectorAccuracyHigh]))
            XCTAssertTrue(detector.features(in:CIImage(cgImage:crop)).contains {($0 as? CIQRCodeFeature)?.messageString==qrPayload})
            let white=try pixels(UIImage(cgImage:try XCTUnwrap(report.cgImage?.cropping(to:.init(x:footer.minX-10,y:footer.minY-10,width:2,height:2)))))
            for c in 0..<3 {XCTAssertEqual(white[c],255)};attach(report,"Climate-actual-complete-\(dark ? "ZH-dark":"EN-light")-2921rows-current-forecast-distinction-SI-realQR")
            m.disappear()
        }
    }
    func testActualPublicHomeUsesSharedShellInRealSceneAndControllerMaintainsFiniteCurrentScience() async throws {
        XCTAssertFalse(UIApplication.shared.connectedScenes.compactMap {$0 as? UIWindowScene}.isEmpty)
        for dark in [false,true] {for size in [CGSize(width:375,height:812),.init(width:812,height:375)] {
            let c=ModuleController(),root=HomeView(headerStyle:.full,qrcode:nil,onCapture:nil,onEvent:nil,controller:c).environment(\.scenePhase,.active).ignoresSafeArea()
            let (window,host)=try await mount(AnyView(root),size:size,dark:dark)
            let ready=await wait {self.drawing(host.view)?.bounds.size==size};XCTAssertTrue(ready)
            c.applyPreset("co2Doubled");c.resume();let progressed=await wait { (self.drawing(host.view)?.snapshotModel?.visibleDay ?? 0)>=14 };XCTAssertTrue(progressed);c.pause()
            let paused=await wait {let s=self.drawing(host.view)?.snapshotModel;return s?.parameters.co2Level == .x2 && (s?.visibleDay ?? 0)>0 && s?.isRunning == false};XCTAssertTrue(paused)
            let state=try XCTUnwrap(drawing(host.view)?.snapshotModel);XCTAssertGreaterThan(state.points[state.visibleDay].scenarioTemp,0);XCTAssertEqual(state.points[0].scenarioTemp,0)
            attach(hierarchy(host.view),"Climate-actual-public-Home-\(dark ? "dark":"light")-\(Int(size.width))x\(Int(size.height))-shared-shell-CO2-controller")
            await unmount(window,host:host)
        }}
    }
    func testActualSwiftUIRemovalRollsBackProbeDisarmsCallbacksAndReleasesHostModelWithinThreeSeconds() async throws {
        var model:ClimateViewModel?=ClimateViewModel();model!.setPreset(.co2Doubled);finish(model!);let mount=ClimateMount(),size=CGSize(width:812,height:375)
        var mounted:(UIWindow,ClimateNativeHost)?=try await self.mount(AnyView(ClimateRemovable(model:model!,mount:mount).ignoresSafeArea()),size:size,dark:false)
        let window=mounted!.0;weak var weakHost=mounted!.1
        let ready=await wait {self.drawing(mounted!.1.view)?.bounds.size==size};XCTAssertTrue(ready)
        var oldView:ClimateDrawingView?=try XCTUnwrap(drawing(mounted!.1.view));weak var weakView=oldView;weak var weakModel=model
        let r=ClimateStageRenderer.plot(in:size);XCTAssertTrue(model!.beginProbe(at:.init(x:r.midX,y:r.midY),size:size));XCTAssertNotNil(model!.probeDay)
        let deadline=CACurrentMediaTime()+3;mount.visible=false
        let removed=await wait(deadline:deadline) {oldView?.onSizeChanged==nil && oldView?.takeRemovalCancellation==nil && self.drawing(mounted!.1.view)==nil && model!.probeDay==nil};XCTAssertTrue(removed)
        oldView=nil;let released=await wait(deadline:deadline) {weakView==nil};XCTAssertTrue(released)
        await unmount(window,host:mounted!.1,deadline:deadline);mounted=nil;model=nil
        let releasedModel=await wait(deadline:deadline) {weakHost==nil && weakModel==nil};XCTAssertTrue(releasedModel);XCTAssertNil(weakHost);XCTAssertNil(weakModel)
    }
    func testPublicCaptureDeliversExactlyOneCompleteRecordAndNoFallback() {
        let m=ClimateViewModel();var deliveries=0;m.deliverCapture(qrcode:nil,style:.light,onCapture:{image in deliveries+=1;XCTAssertNotNil(image.pngData())},fallback:{_ in XCTFail("Unexpected fallback")});XCTAssertEqual(deliveries,1);m.disappear()
    }
    private func mount(_ root:AnyView,size:CGSize,dark:Bool) async throws ->(UIWindow,ClimateNativeHost) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap {$0 as? UIWindowScene}.first)
        let window = UIWindow(windowScene:scene);window.frame = .init(origin:.zero,size:size);window.overrideUserInterfaceStyle = dark ? .dark:.light
        let host = ClimateNativeHost(rootView:AnyView(root.environment(\.colorScheme,dark ? .dark:.light)))
        host.previousKeyWindow = scene.windows.first(where:\.isKeyWindow);window.rootViewController = host;window.makeKeyAndVisible()
        let ready = await wait {host.appeared};XCTAssertTrue(ready);host.view.layoutIfNeeded();return(window,host)
    }
    private func unmount(_ window:UIWindow,host:ClimateNativeHost,deadline:CFTimeInterval? = nil) async {
        window.isHidden = true;window.rootViewController = nil
        let removed = await wait(deadline:deadline) {host.disappeared};XCTAssertTrue(removed);host.previousKeyWindow?.makeKeyAndVisible();await Task.yield()
    }
    private func wait(deadline:CFTimeInterval? = nil,_ condition:()->Bool) async ->Bool {
        let end = deadline ?? (CACurrentMediaTime()+3)
        while !condition(),CACurrentMediaTime()<end {try? await Task.sleep(nanoseconds:20_000_000)};return condition()
    }
    private func drawing(_ view:UIView)->ClimateDrawingView? {if let view = view as? ClimateDrawingView {return view};for child in view.subviews {if let match = drawing(child) {return match}};return nil}
    private func hierarchy(_ view:UIView)->UIImage {
        view.layoutIfNeeded();let f = UIGraphicsImageRendererFormat();f.scale = 1;f.opaque = true
        return UIGraphicsImageRenderer(size:view.bounds.size,format:f).image {context in
            UIColor.systemBackground.setFill();context.fill(view.bounds);XCTAssertTrue(view.drawHierarchy(in:view.bounds,afterScreenUpdates:true))
        }
    }
    private func pixels(_ image:UIImage) throws ->[UInt8] {
        let cg = try XCTUnwrap(image.cgImage);var p = [UInt8](repeating:0,count:cg.width*cg.height*4)
        try p.withUnsafeMutableBytes {buffer in let cgContext = try XCTUnwrap(CGContext(data:buffer.baseAddress,width:cg.width,height:cg.height,bitsPerComponent:8,bytesPerRow:cg.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue|CGBitmapInfo.byteOrder32Big.rawValue));cgContext.draw(cg,in:.init(x:0,y:0,width:cg.width,height:cg.height))};return p
    }
    private func coloredCount(_ image:UIImage,rect:CGRect,color:String) throws ->Int {
        let cg = try XCTUnwrap(image.cgImage),clipped = rect.intersection(.init(x:0,y:0,width:cg.width,height:cg.height))
        guard clipped.width>0,clipped.height>0 else {return 0}
        let crop = try XCTUnwrap(cg.cropping(to:clipped)),p = try pixels(UIImage(cgImage:crop))
        var count = 0
        for i in stride(from:0,to:p.count,by:4) {
            let red = Int(p[i]), green = Int(p[i+1]), blue = Int(p[i+2])
            let primary = red-green>60 && red-blue>100
            let transmission = blue-green>35 && red-green>20 && red>90
            if color == "blue" ? primary : transmission { count += 1 }
        }
        return count
    }
    private func realQR() throws ->UIImage {
        let filter = try XCTUnwrap(CIFilter(name:"CIQRCodeGenerator"));filter.setValue(Data(qrPayload.utf8),forKey:"inputMessage");filter.setValue("M",forKey:"inputCorrectionLevel")
        let output = try XCTUnwrap(filter.outputImage).transformed(by:.init(scaleX:4,y:4));return UIImage(cgImage:try XCTUnwrap(CIContext().createCGImage(output,from:output.extent)))
    }
    private func attach(_ image:UIImage,_ name:String) {let a = XCTAttachment(image:image);a.name = name;a.lifetime = .keepAlways;add(a)}
}
@MainActor private final class ClimateMount:ObservableObject {@Published var visible = true}
@MainActor private struct ClimateRemovable:View {
    @ObservedObject var model:ClimateViewModel
    @ObservedObject var mount:ClimateMount
    var body:some View {if mount.visible {ClimateStageContent(model:model,colorScheme:.light)} else {Color.clear}}
}
