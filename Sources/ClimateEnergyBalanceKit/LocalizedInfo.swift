import UIKit

public enum LocalizedInfo {
    public static var Name: String {
        localized("module.title")
    }

    public static var Description: String {
        localized("module.subtitle")
    }

    public static var Title: String {
        localized("module.title")
    }

    public static var Subtitle: String {
        localized("module.subtitle")
    }

    public static var logo: UIImage {
        if let image = UIImage(named: "logo", in: .module, with: nil) {
            return image
        }
        return generatedPlaceholder()
    }

    static func localized(_ key: String) -> String {
        let localizedText = Bundle.module.localizedString(forKey: key, value: nil, table: nil)
        if localizedText != key {
            return localizedText
        }

        if let path = Bundle.module.path(forResource: "en", ofType: "lproj"),
           let englishBundle = Bundle(path: path) {
            let fallback = englishBundle.localizedString(forKey: key, value: nil, table: nil)
            if fallback != key {
                return fallback
            }
        }

        return key
    }

    private static func generatedPlaceholder() -> UIImage {
        let size = CGSize(width: 240, height: 240)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cg = context.cgContext
            let rect = CGRect(origin: .zero, size: size)
            let colors = [
                UIColor(red: 0.04, green: 0.09, blue: 0.24, alpha: 1).cgColor,
                UIColor(red: 0.18, green: 0.64, blue: 0.95, alpha: 1).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0, 1]

            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            } else {
                UIColor.systemBlue.setFill()
                cg.fill(rect)
            }

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 78, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            "EBM".draw(in: CGRect(x: 0, y: 74, width: size.width, height: 92), withAttributes: attributes)
        }
    }
}
