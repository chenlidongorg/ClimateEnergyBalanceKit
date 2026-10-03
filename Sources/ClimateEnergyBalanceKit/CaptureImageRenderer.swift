import UIKit

struct ClimateCaptureText {
    let text: String
    let rect: CGRect
    let fontSize: CGFloat
}
struct ClimateCaptureLayout {
    let canvas: CGSize
    let stage: CGRect
    let texts: [ClimateCaptureText]
    let qrcode: CGRect?
}
enum CaptureImageRenderer {
    static func sanitizedSize(_ size: CGSize) -> CGSize {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return .init(width: 360, height: 420) }
        let factor = min(1, 12000/max(size.width,size.height))
        return .init(width:max(2,size.width*factor),height:max(2,size.height*factor))
    }
    static func stage(snapshot: ClimateStageSnapshot, size: CGSize, userInterfaceStyle: UIUserInterfaceStyle = .light) -> UIImage {
        let safe = sanitizedSize(size),f=UIGraphicsImageRendererFormat();f.scale=1;f.opaque=true;f.preferredRange = .standard
        return UIGraphicsImageRenderer(size:safe,format:f).image {ClimateStageRenderer.draw(snapshot:snapshot,in:$0.cgContext,size:safe,trait:.init(userInterfaceStyle:userInterfaceStyle))}
    }
    static func layout(snapshot: ClimateCaptureSnapshot, size: CGSize, hasQRCode: Bool) -> ClimateCaptureLayout {
        let safe=sanitizedSize(size),width=ceil(safe.width),stage=CGRect(x:0,y:0,width:width,height:ceil(safe.height)),margin:CGFloat=18
        var rows:[ClimateCaptureText]=[],y=stage.maxY+18
        let summaries=snapshot.texts.isEmpty ? [snapshot.title,snapshot.subtitle,snapshot.presetName] : snapshot.texts
        for (index,text) in summaries.enumerated() {
            let font:CGFloat=index==0 ? 22:14
            let rect=CGRect(x:margin,y:y,width:width-2*margin,height:measured(text,width:width-2*margin,font:font))
            rows.append(.init(text:text,rect:rect,fontSize:font));y=rect.maxY+8
        }
        let columns = width >= 700 ? 3:2,spacing:CGFloat=12,cell=(width-margin*2-spacing*CGFloat(columns-1))/CGFloat(columns)
        let points=snapshot.points.isEmpty ? snapshot.scenarioSeries.enumerated().map { ClimateSeriesPoint(day:$0.offset,baselineTemp:snapshot.baselineSeries.indices.contains($0.offset) ? snapshot.baselineSeries[$0.offset]:0,scenarioTemp:$0.element) } : snapshot.points
        for begin in stride(from:0,to:points.count,by:columns) {
            var line:[ClimateCaptureText]=[]
            for c in 0..<columns where begin+c<points.count {
                let p=points[begin+c],text=String(format:"%d,%.12g,%.12g",p.day,p.baselineTemp,p.scenarioTemp)
                line.append(.init(text:text,rect:CGRect(x:margin+CGFloat(c)*(cell+spacing),y:y,width:cell,height:measured(text,width:cell,font:14)),fontSize:14))
            }
            y+=(line.map {$0.rect.height}.max() ?? 0)+4;rows+=line
        }
        var qr:CGRect?
        if hasQRCode {y+=24;let edge=min(160,max(80,width-68));qr=CGRect(x:(width-edge)/2,y:y+16,width:edge,height:edge);y+=edge+32}
        return .init(canvas:.init(width:width,height:ceil(y+margin)),stage:stage,texts:rows,qrcode:qr)
    }
    static func render(snapshot: ClimateCaptureSnapshot, size: CGSize = .init(width:360,height:420), qrcode: UIImage? = nil,
                       userInterfaceStyle: UIUserInterfaceStyle = .light, stageImage: UIImage? = nil) -> UIImage {
        let safe=sanitizedSize(size),f=UIGraphicsImageRendererFormat();f.scale=1;f.opaque=true;f.preferredRange = .standard
        let l=layout(snapshot:snapshot,size:safe,hasQRCode:qrcode != nil),trait=UITraitCollection(userInterfaceStyle:userInterfaceStyle)
        var image=UIImage()
        trait.performAsCurrent {
            image=UIGraphicsImageRenderer(size:l.canvas,format:f).image {context in
                let cg=context.cgContext;cg.setFillColor(UIColor.systemBackground.resolvedColor(with:trait).cgColor);cg.fill(.init(origin:.zero,size:l.canvas))
                let points=snapshot.points.isEmpty ? [ClimateSeriesPoint(day:0,baselineTemp:0,scenarioTemp:0)] : snapshot.points
                let state=snapshot.stage ?? .init(points:points,visibleDay:points.last!.day,probeDay:nil,localeIdentifier:"en",parameters:ClimatePreset.baseline.parameters)
                let native=stageImage ?? stage(snapshot:state,size:safe,userInterfaceStyle:userInterfaceStyle)
                cg.interpolationQuality = .none
                if let nativeCG=native.cgImage {UIImage(cgImage:nativeCG).draw(in:l.stage)}
                for row in l.texts {(row.text as NSString).draw(in:row.rect,withAttributes:attributes(font:row.fontSize))}
                if let qrcode,let qr=l.qrcode {UIColor.white.setFill();cg.fill(qr.insetBy(dx:-16,dy:-16));cg.interpolationQuality = .none;qrcode.draw(in:qr)}
            }
        };return image
    }
    static func attributes(font:CGFloat) ->[NSAttributedString.Key:Any] {
        let p=NSMutableParagraphStyle();p.lineBreakMode = .byWordWrapping
        return [.font:UIFont.systemFont(ofSize:font),.foregroundColor:UIColor.label,.paragraphStyle:p]
    }
    private static func measured(_ text:String,width:CGFloat,font:CGFloat)->CGFloat {
        ceil((text as NSString).boundingRect(with:.init(width:width,height:.greatestFiniteMagnitude),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:attributes(font:font),context:nil).height)+3
    }
}
