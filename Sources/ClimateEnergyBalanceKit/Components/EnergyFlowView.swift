import SwiftUI

struct EnergyFlowView: View {
    let absorbed: Double
    let outgoing: Double
    let netForcing: Double

    private var maxMagnitude: Double {
        max(abs(absorbed), abs(outgoing), abs(netForcing), 1)
    }

    var body: some View {
        VStack(spacing: 12) {
            flowRow(
                title: LocalizedInfo.localized("metric.absorbed"),
                value: absorbed,
                tint: .yellow
            )
            flowRow(
                title: LocalizedInfo.localized("metric.outgoing"),
                value: outgoing,
                tint: .blue
            )
            flowRow(
                title: LocalizedInfo.localized("metric.netForcing"),
                value: netForcing,
                tint: netForcing >= 0 ? .red : .green
            )
        }
    }

    private func flowRow(title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(String(format: "%.2f W/m²", value))
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }

            GeometryReader { proxy in
                let width = max(2, proxy.size.width * CGFloat(abs(value) / maxMagnitude))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(tint.opacity(0.85))
                        .frame(width: width)
                }
            }
            .frame(height: 12)
        }
    }
}
