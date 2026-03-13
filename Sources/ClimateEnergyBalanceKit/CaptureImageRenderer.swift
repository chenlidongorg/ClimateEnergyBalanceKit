import UIKit

enum CaptureImageRenderer {
    static func render(snapshot: ClimateCaptureSnapshot, qrcode: UIImage?) -> UIImage {
        let size = CGSize(width: 1260, height: 1520)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cg = context.cgContext
            UIColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1).setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            drawHeader(snapshot: snapshot, qrcode: qrcode)
            drawCurveCard(snapshot: snapshot, in: cg)
            drawMetricsCard(snapshot: snapshot, in: cg)
            drawFooter()
        }
    }

    private static func drawHeader(snapshot: ClimateCaptureSnapshot, qrcode: UIImage?) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 54, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 27, weight: .regular),
            .foregroundColor: UIColor(white: 0.82, alpha: 1)
        ]

        snapshot.title.draw(in: CGRect(x: 72, y: 70, width: 900, height: 70), withAttributes: titleAttributes)
        snapshot.subtitle.draw(in: CGRect(x: 72, y: 142, width: 980, height: 38), withAttributes: subtitleAttributes)

        if let qrcode {
            qrcode.draw(in: CGRect(x: 1062, y: 74, width: 126, height: 126))
        }
    }

    private static func drawCurveCard(snapshot: ClimateCaptureSnapshot, in cg: CGContext) {
        let card = CGRect(x: 56, y: 232, width: 1148, height: 700)
        drawCard(card, in: cg)
        drawText(
            LocalizedInfo.localized("capture.curve"),
            frame: CGRect(x: card.minX + 30, y: card.minY + 24, width: 540, height: 44),
            font: .systemFont(ofSize: 36, weight: .semibold),
            color: .white
        )

        let plot = CGRect(x: card.minX + 30, y: card.minY + 92, width: card.width - 60, height: 390)
        drawSeries(snapshot.baselineSeries, rect: plot, color: UIColor(red: 0.58, green: 0.62, blue: 0.70, alpha: 1))
        drawSeries(snapshot.scenarioSeries, rect: plot, color: UIColor(red: 0.94, green: 0.38, blue: 0.31, alpha: 1))

        drawText(
            "\(LocalizedInfo.localized("parameter.solar")) \(String(format: "%.3f×", snapshot.solarMultiplier))   \(LocalizedInfo.localized("parameter.albedo")) \(String(format: "%.2f", snapshot.albedo))",
            frame: CGRect(x: card.minX + 30, y: card.minY + 516, width: 1040, height: 34),
            font: .monospacedSystemFont(ofSize: 24, weight: .medium),
            color: UIColor(white: 0.84, alpha: 1)
        )

        drawText(
            "CO₂ \(snapshot.co2Name)   \(LocalizedInfo.localized("parameter.heatCapacity")) \(snapshot.heatCapacityName)   \(LocalizedInfo.localized("parameter.feedback")) \(snapshot.feedbackName)",
            frame: CGRect(x: card.minX + 30, y: card.minY + 558, width: 1080, height: 34),
            font: .systemFont(ofSize: 23, weight: .regular),
            color: UIColor(white: 0.78, alpha: 1)
        )
    }

    private static func drawMetricsCard(snapshot: ClimateCaptureSnapshot, in cg: CGContext) {
        let card = CGRect(x: 56, y: 968, width: 1148, height: 300)
        drawCard(card, in: cg)
        drawText(
            LocalizedInfo.localized("section.metrics"),
            frame: CGRect(x: card.minX + 30, y: card.minY + 24, width: 520, height: 44),
            font: .systemFont(ofSize: 36, weight: .semibold),
            color: .white
        )

        drawText(
            "\(LocalizedInfo.localized("metric.equilibrium")): \(String(format: "%.2f°C", snapshot.equilibriumTemperature))",
            frame: CGRect(x: card.minX + 30, y: card.minY + 94, width: 760, height: 36),
            font: .monospacedSystemFont(ofSize: 25, weight: .medium),
            color: UIColor(white: 0.84, alpha: 1)
        )
        drawText(
            "\(LocalizedInfo.localized("metric.timeConstant")): \(String(format: "%.1f y", snapshot.timeConstantYears))",
            frame: CGRect(x: card.minX + 30, y: card.minY + 146, width: 700, height: 36),
            font: .monospacedSystemFont(ofSize: 25, weight: .medium),
            color: UIColor(white: 0.84, alpha: 1)
        )
        drawText(
            "\(LocalizedInfo.localized("section.preset")): \(snapshot.presetName)",
            frame: CGRect(x: card.minX + 30, y: card.minY + 198, width: 900, height: 36),
            font: .systemFont(ofSize: 24, weight: .regular),
            color: UIColor(white: 0.78, alpha: 1)
        )
    }

    private static func drawFooter() {
        drawText(
            LocalizedInfo.localized("capture.disclaimer"),
            frame: CGRect(x: 72, y: 1430, width: 1120, height: 34),
            font: .systemFont(ofSize: 21, weight: .regular),
            color: UIColor(white: 0.72, alpha: 1)
        )
    }

    private static func drawCard(_ rect: CGRect, in cg: CGContext) {
        UIColor(red: 0.10, green: 0.12, blue: 0.17, alpha: 1).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 28).fill()
        cg.setStrokeColor(UIColor(white: 1, alpha: 0.06).cgColor)
        cg.setLineWidth(1)
        cg.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
    }

    private static func drawSeries(_ values: [Double], rect: CGRect, color: UIColor) {
        guard values.count > 1 else { return }
        let minValue = min(values.min() ?? 0, 0)
        let maxValue = max(values.max() ?? 0, 0.01)
        let range = max(0.01, maxValue - minValue)

        UIColor(white: 1, alpha: 0.08).setStroke()
        UIBezierPath(roundedRect: rect, cornerRadius: 12).stroke()

        let path = UIBezierPath()
        for index in values.indices {
            let x = rect.minX + CGFloat(index) / CGFloat(values.count - 1) * rect.width
            let normalized = (values[index] - minValue) / range
            let y = rect.maxY - CGFloat(normalized) * rect.height
            if index == values.startIndex {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        color.setStroke()
        path.lineWidth = 3
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.stroke()
    }

    private static func drawText(
        _ text: String,
        frame: CGRect,
        font: UIFont,
        color: UIColor
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        text.draw(in: frame, withAttributes: attributes)
    }
}
