# Public API + Event Bridge Contract

This contract freezes each kit's public metadata surface, public view entry, event output, and host control channel before implementation.

Applies to every new kit planned under `NextSPMs`.

---

## 0) Contract Target

Goals:
- Each SPM manages its own `title/subtitle/logo` (not hosted by app side).
- External apps can import and use the SPM directly with a stable public API.
- Host app can both receive module events and send control commands.

---

## 1) Per-SPM Metadata Self-Management (required)

Each kit must keep metadata and assets in its own package:
- `Sources/<KitName>/LocalizedInfo.swift`
- `Sources/<KitName>/Resources/logo.png`
- `Sources/<KitName>/Resources/logo_placeholder.png`
- `Sources/<KitName>/Resources/en.lproj/Localizable.strings`
- `Sources/<KitName>/Resources/zh-Hans.lproj/Localizable.strings`

Required string keys:
- `module.title`
- `module.subtitle`

Required public shape (names fixed):

```swift
public struct ModuleMetadata {
  public let identifier: String
  public let title: String
  public let subtitle: String
  public let logo: UIImage
  public let category: String
  public let minimumIOSVersion: String
}

public enum ModuleInfo {
  public static var metadata: ModuleMetadata { get }
}
```

Rules:
- `identifier` must be reverse-domain and stable (example: `org.endlessai.quantum-circuit`).
- `title/subtitle` must localize by current locale and fallback to English.
- `minimumIOSVersion` records the kit implementation target (normally `15.0` or `16.0`), while product baseline remains iOS 13 at app level.
- `logo` must always return an image:
  - first: `logo`
  - second: `logo_placeholder`
  - final: generated system placeholder

---

## 2) Public View Entry Contract (required)

Each kit must expose:

```swift
public struct HomeView: View

public init(
  headerStyle: HeaderStyle = .full,
  qrcode: UIImage? = nil,
  onCapture: ((UIImage) -> Void)? = nil,
  onEvent: ((ModuleEvent) -> Void)? = nil,
  controller: ModuleController? = nil
)
```

Semantics:
- `onCapture`: module -> host export callback.
- `onEvent`: module -> host event callback.
- `controller`: host -> module control channel.

`onEvent` and `controller` are optional in use, but mandatory in signature.

---

## 3) Event Output Contract (module -> host)

Required event model:

```swift
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
```

Required minimum events:
- `lifecycle.appeared`
- `lifecycle.disappeared`
- `interaction.parameterChanged`
- `interaction.captureTapped`
- `business.experimentStarted`
- `business.experimentReset`
- `error(code:message:)` for recoverable runtime failures

Payload rules:
- no PII
- payload must stay lightweight and string-serializable

---

## 4) Host Control Contract (host -> module)

Control type:

```swift
public final class ModuleController: ObservableObject {
  public var onReset: (() -> Void)?
  public var onPause: (() -> Void)?
  public var onResume: (() -> Void)?
  public var onApplyPreset: ((String) -> Void)?
  public var onSetParameter: ((String, Double) -> Void)?
}
```

Required commands:
- `reset`
- `applyPreset`
- `setParameter`

Optional commands:
- `pause/resume` (animated modules only)

If a command is unsupported, module must ignore safely and emit:
- `ModuleEvent.custom(name: "unsupported_command", payload: ...)`

---

## 5) External App Quick Start (required in kit README)

Every public kit README must include:
1. SwiftPM dependency URL + version/tag
2. `import <KitName>`
3. Read metadata without UI mount:

```swift
let metadata = ModuleInfo.metadata
print(metadata.title, metadata.subtitle)
```

4. Embed view with event/control bridge:

```swift
let controller = ModuleController()
HomeView(onEvent: { event in
  print(event)
}, controller: controller)
```

---

## 6) Optional Notification Bridge

If callback passing is hard in host architecture, a Notification bridge can be added.

Rules:
- notification name must be prefixed with module identifier
- userInfo keys must be documented in the kit README
- callback API remains the primary contract

---

## 7) Versioning and Stability

Breaking changes include:
- `HomeView` init signature
- `ModuleMetadata` fields
- `ModuleEvent` cases and payload semantics
- `ModuleController` command surface

For breaking changes:
- bump major version
- provide migration notes in kit README and release notes

---

## 8) Public-Ready SPM Checklist

Before declaring a kit "public-ready":
- no app-private dependencies (`AppsKit`, internal workspace-only modules)
- product compatibility baseline documented as iOS 13, with module-level target documented as iOS 15/16 if needed
- package builds on iOS device + simulator (`arm64` and `x86_64`)
- README includes quick start and event/control usage
- localized metadata exists (`en`, `zh-Hans` minimum)
- logo and placeholder assets both present
