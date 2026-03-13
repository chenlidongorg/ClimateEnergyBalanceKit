import SwiftUI
import UIKit

struct ClimateHeaderView: View {
    let style: HeaderStyle
    let qrcode: UIImage?

    var body: some View {
        Group {
            switch style {
            case .hidden:
                EmptyView()
            case .simple:
                Text(LocalizedInfo.Subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            case .full:
                HStack(spacing: 14) {
                    Image(uiImage: LocalizedInfo.logo)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedInfo.Title)
                            .font(.headline)
                        Text(LocalizedInfo.Subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let qrcode {
                        Image(uiImage: qrcode)
                            .resizable()
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(Color(.secondarySystemBackground))
    }
}
