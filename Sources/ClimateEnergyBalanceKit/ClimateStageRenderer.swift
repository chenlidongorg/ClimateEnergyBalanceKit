import UIKit

/// One common temperature axis and fixed 0...8 year domain for both curves.
/// Curve bounds include the complete forecast so advancing the clock never rescales it.
enum ClimateStageRenderer {
    static func plot(in size: CGSize) -> CGRect {
        CGRect(x: 56, y: max(110, size.height * 0.43), width: max(1, size.width - 76), height: max(30, size.height * 0.47 - 28))
    }
    static func temperatureRange(_ snapshot: ClimateStageSnapshot) -> ClosedRange<Double> {
        let values = snapshot.points.map(\.scenarioTemp)
        let lo = min(0, values.min() ?? 0), hi = max(0, values.max() ?? 0), pad = max(0.25, (hi - lo) * 0.12)
        return (lo - pad)...(hi + pad)
    }
    static func coordinate(day: Int, temperature: Double, snapshot: ClimateStageSnapshot, size: CGSize) -> CGPoint {
        let r = plot(in: size), bounds = temperatureRange(snapshot)
        return .init(x: r.minX + CGFloat(day)/CGFloat(max(1, snapshot.points.last?.day ?? 1)) * r.width,
            y: r.maxY - CGFloat((temperature - bounds.lowerBound)/(bounds.upperBound - bounds.lowerBound)) * r.height)
    }
    static func draw(snapshot s: ClimateStageSnapshot, in cg: CGContext, size: CGSize, trait: UITraitCollection) {
        let background = UIColor.systemBackground.resolvedColor(with: trait)
        cg.setFillColor(background.cgColor); cg.fill(CGRect(x: 0, y: 0, width: ceil(size.width), height: ceil(size.height)))
        let label = UIColor.label.resolvedColor(with: trait), secondary = UIColor.secondaryLabel.resolvedColor(with: trait)
        let grid = UIColor.separator.resolvedColor(with: trait), orange = UIColor.systemOrange.resolvedColor(with: trait)
        let purple = UIColor.systemPurple.resolvedColor(with: trait)
        let p = s.points[min(max(0, s.observedDay), max(0, s.points.count - 1))]
        let m = ClimateEnergySimulator.metrics(parameters: s.parameters, temperature: p.scenarioTemp)
        let center = CGPoint(x: size.width/2, y: max(78, size.height*0.25)), radius = min(36, size.height*0.075)
        cg.setFillColor(UIColor.systemGray5.resolvedColor(with: trait).cgColor)
        cg.fillEllipse(in: CGRect(x: center.x-radius, y: center.y-radius, width: radius*2, height: radius*2))
        cg.setStrokeColor(secondary.cgColor); cg.setLineWidth(1.5)
        cg.strokeEllipse(in: CGRect(x: center.x-radius, y: center.y-radius, width: radius*2, height: radius*2))
        drawText("EBM", at: CGRect(x: center.x-radius, y: center.y-9, width: radius*2, height: 22), font: 14, color: label, align: .center)
        let reach = max(30, min(size.width*0.31, 180)), maxFlux = max(340, m.absorbedShortwave, m.outgoingLongwave)
        arrow(from: CGPoint(x: center.x-radius-reach*CGFloat(m.absorbedShortwave/maxFlux), y: center.y), to: CGPoint(x: center.x-radius-4, y: center.y), color: orange, dashed: false, cg: cg)
        arrow(from: CGPoint(x: center.x+radius+4, y: center.y), to: CGPoint(x: center.x+radius+reach*CGFloat(max(0,m.outgoingLongwave)/maxFlux), y: center.y), color: purple, dashed: true, cg: cg)
        drawText("SW", at: CGRect(x: 12, y: center.y+14, width: center.x-radius-24, height: 20), font: 12, color: secondary, align: .center)
        drawText("LW", at: CGRect(x: center.x+radius+10, y: center.y+14, width: max(10, center.x-radius-22), height: 20), font: 12, color: secondary, align: .center)
        let r = plot(in: size), bounds = temperatureRange(s)
        drawText("ΔT (K)", at: CGRect(x: r.minX, y: r.minY-24, width: 130, height: 20), font: 12, color: secondary)
        for tick in 0...4 {
            let t = bounds.lowerBound + (bounds.upperBound - bounds.lowerBound) * Double(tick)/4
            let y = r.maxY - r.height*CGFloat(tick)/4
            cg.setStrokeColor(grid.cgColor); cg.setLineWidth(0.5); cg.move(to: CGPoint(x:r.minX,y:y));cg.addLine(to: CGPoint(x:r.maxX,y:y));cg.strokePath()
            drawText(String(format:"%.2g",t), at:CGRect(x:0,y:y-8,width:r.minX-6,height:18),font:11,color:secondary,align:.right)
        }
        cg.setStrokeColor(secondary.cgColor);cg.setLineWidth(1);cg.move(to:CGPoint(x:r.minX,y:r.minY));cg.addLine(to:CGPoint(x:r.minX,y:r.maxY));cg.addLine(to:CGPoint(x:r.maxX,y:r.maxY));cg.strokePath()
        for tick in 0...4 {
            let day = Double(s.points.last?.day ?? 2920)*Double(tick)/4
            drawText(String(format:"%.2g",day/365),at:CGRect(x:r.minX+r.width*CGFloat(tick)/4-17,y:r.maxY+5,width:34,height:18),font:11,color:secondary,align:.center)
        }
        drawText("t (y)",at:CGRect(x:r.maxX-55,y:r.maxY+24,width:55,height:18),font:12,color:secondary,align:.right)
        cg.saveGState();cg.clip(to:r.insetBy(dx:-1,dy:-1))
        func xy(_ day: Int, _ temperature: Double) -> CGPoint {
            .init(x: r.minX + CGFloat(day) / CGFloat(max(1, s.points.last?.day ?? 1)) * r.width,
                  y: r.maxY - CGFloat((temperature - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * r.height)
        }
        for isBaseline in [true,false] {
            cg.setStrokeColor((isBaseline ? secondary:orange).cgColor);cg.setLineWidth(isBaseline ? 1.5:2.5);cg.setLineDash(phase:0,lengths:isBaseline ? [5,4]:[])
            for (index,point) in s.points.prefix(max(1,s.visibleDay+1)).enumerated() {
                let position = xy(point.day, isBaseline ? point.baselineTemp : point.scenarioTemp)
                if index==0 {cg.move(to:position)} else {cg.addLine(to:position)}
            };cg.strokePath()
        }
        cg.setLineDash(phase:0,lengths:[])
        let dot=xy(s.observedDay, p.scenarioTemp)
        if s.probeDay != nil { cg.setStrokeColor(label.withAlphaComponent(0.45).cgColor);cg.setLineWidth(1);cg.move(to:CGPoint(x:dot.x,y:r.minY));cg.addLine(to:CGPoint(x:dot.x,y:r.maxY));cg.strokePath() }
        cg.setFillColor(orange.cgColor);cg.fillEllipse(in:CGRect(x:dot.x-4,y:dot.y-4,width:8,height:8));cg.restoreGState()
    }
    private static func arrow(from a:CGPoint,to b:CGPoint,color:UIColor,dashed:Bool,cg:CGContext) {
        guard abs(b.x-a.x)>2 else{return};cg.setStrokeColor(color.cgColor);cg.setLineWidth(2);cg.setLineDash(phase:0,lengths:dashed ? [5,4]:[]);cg.move(to:a);cg.addLine(to:b);cg.strokePath();cg.setLineDash(phase:0,lengths:[]);cg.move(to:CGPoint(x:b.x-6,y:b.y-5));cg.addLine(to:b);cg.addLine(to:CGPoint(x:b.x-6,y:b.y+5));cg.strokePath()
    }
    private static func drawText(_ text:String,at rect:CGRect,font:CGFloat,color:UIColor,align:NSTextAlignment = .left) {
        let p=NSMutableParagraphStyle();p.alignment=align;(text as NSString).draw(in:rect,withAttributes:[.font:UIFont.systemFont(ofSize:font),.foregroundColor:color,.paragraphStyle:p])
    }
}
