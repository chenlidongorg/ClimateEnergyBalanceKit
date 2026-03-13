import SwiftUI

struct TemperatureLineChartView: View {
    let points: [ClimateSeriesPoint]

    private var minValue: Double {
        min(points.map(\.baselineTemp).min() ?? 0, points.map(\.scenarioTemp).min() ?? 0)
    }

    private var maxValue: Double {
        max(points.map(\.baselineTemp).max() ?? 0, points.map(\.scenarioTemp).max() ?? 0)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.18))

                if points.count < 2 {
                    Text("--")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .padding(12)
                } else {
                    Path { path in
                        drawSeries(path: &path, values: points.map(\.baselineTemp), in: geometry.size)
                    }
                    .stroke(Color(red: 0.59, green: 0.63, blue: 0.70), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                    Path { path in
                        drawSeries(path: &path, values: points.map(\.scenarioTemp), in: geometry.size)
                    }
                    .stroke(Color(red: 0.94, green: 0.38, blue: 0.31), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: 230)
    }

    private func drawSeries(path: inout Path, values: [Double], in size: CGSize) {
        guard values.count > 1 else { return }

        let leftPadding: CGFloat = 12
        let rightPadding: CGFloat = 12
        let topPadding: CGFloat = 12
        let bottomPadding: CGFloat = 14
        let width = max(1, size.width - leftPadding - rightPadding)
        let height = max(1, size.height - topPadding - bottomPadding)
        let span = max(0.01, maxValue - minValue)

        for index in values.indices {
            let x = leftPadding + CGFloat(index) / CGFloat(values.count - 1) * width
            let normalized = (values[index] - minValue) / span
            let y = topPadding + (1 - CGFloat(normalized)) * height
            if index == values.startIndex {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
}
