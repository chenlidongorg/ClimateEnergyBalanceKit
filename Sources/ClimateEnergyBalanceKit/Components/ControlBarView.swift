import SwiftUI

struct ControlBarView: View {
    let isRunning: Bool
    let isCaptureConfirmed: Bool
    let onCapture: () -> Void
    let onToggleRun: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Button(action: onCapture) {
                Image(systemName: isCaptureConfirmed ? "checkmark" : "camera.shutter.button.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(isCaptureConfirmed ? .green : .primary)
                    .scaleEffect(isCaptureConfirmed ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.18), value: isCaptureConfirmed)
                    .frame(width: 52, height: 52)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .accessibilityLabel(
                isCaptureConfirmed
                    ? LocalizedInfo.localized("action.captureSaved")
                    : LocalizedInfo.localized("action.capture")
            )
            .buttonStyle(.plain)

            Button(action: onToggleRun) {
                Image(systemName: isRunning ? "pause" : "play")
                    .font(.title2.weight(.semibold))
                    .frame(width: 92, height: 52)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .accessibilityLabel(
                isRunning
                    ? LocalizedInfo.localized("action.pause")
                    : LocalizedInfo.localized("action.run")
            )
            .buttonStyle(.plain)

            Button(action: onReset) {
                Label(LocalizedInfo.localized("action.reset"), systemImage: "arrow.triangle.2.circlepath")
                    .labelStyle(.iconOnly)
                    .frame(width: 52, height: 52)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .accessibilityLabel(LocalizedInfo.localized("action.reset"))
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground).opacity(0.92))
        .clipShape(Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
