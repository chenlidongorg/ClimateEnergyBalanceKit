import SwiftUI
import UIKit

public enum HeaderStyle {
    case full
    case simple
    case hidden
}

public struct ModuleMetadata {
    public let identifier: String
    public let title: String
    public let subtitle: String
    public let logo: UIImage
    public let category: String
    public let minimumIOSVersion: String

    public init(
        identifier: String,
        title: String,
        subtitle: String,
        logo: UIImage,
        category: String,
        minimumIOSVersion: String
    ) {
        self.identifier = identifier
        self.title = title
        self.subtitle = subtitle
        self.logo = logo
        self.category = category
        self.minimumIOSVersion = minimumIOSVersion
    }
}

public enum ModuleInfo {
    public static var metadata: ModuleMetadata {
        ModuleMetadata(
            identifier: "org.endlessai.climate-energy-balance-kit",
            title: LocalizedInfo.Title,
            subtitle: LocalizedInfo.Subtitle,
            logo: LocalizedInfo.logo,
            category: "physics",
            minimumIOSVersion: "15.0"
        )
    }
}

public enum ModuleEvent {
    case lifecycle(ModuleLifecycleEvent)
    case interaction(ModuleInteractionEvent)
    case business(ModuleBusinessEvent)
    case error(code: String, message: String)
    case custom(name: String, payload: [String: String])
}

public enum ModuleLifecycleEvent: String {
    case appeared
    case disappeared
}

public enum ModuleInteractionEvent {
    case parameterChanged(key: String, value: String)
    case captureTapped
    case presetChanged(name: String)
}

public enum ModuleBusinessEvent: String {
    case experimentStarted
    case experimentReset
    case experimentCompleted
}

public final class ModuleController: ObservableObject {
    public var onReset: (() -> Void)?
    public var onPause: (() -> Void)?
    public var onResume: (() -> Void)?
    public var onApplyPreset: ((String) -> Void)?
    public var onSetParameter: ((String, Double) -> Void)?

    public init() {}

    public func reset() {
        onReset?()
    }

    public func pause() {
        onPause?()
    }

    public func resume() {
        onResume?()
    }

    public func applyPreset(_ name: String) {
        onApplyPreset?(name)
    }

    public func setParameter(_ key: String, value: Double) {
        onSetParameter?(key, value)
    }
}
