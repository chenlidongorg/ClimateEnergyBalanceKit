# ClimateEnergyBalanceKit

Interactive climate energy-balance simulator for education.

## Add with SwiftPM

```swift
.package(url: "https://github.com/chenlidongorg/ClimateEnergyBalanceKit.git", branch: "main")
```

Then add product:

```swift
.product(name: "ClimateEnergyBalanceKit", package: "ClimateEnergyBalanceKit")
```

## Quick Start

```swift
import ClimateEnergyBalanceKit

let metadata = ModuleInfo.metadata
print(metadata.title, metadata.subtitle)

let controller = ModuleController()
let view = HomeView(
    onCapture: { image in
        print("captured:", image.size)
    },
    onEvent: { event in
        print(event)
    },
    controller: controller
)
```

## Public Contract

- PRD: `./PRD.md`
- API/Event contract: `./MODULE_API_CONTRACT.md`
- Implementation checklist: `./MODULE_IMPLEMENTATION_CHECKLIST.md`

## Compatibility

- Package manifest and interactive HomeView: iOS 15+ (existing minimum preserved)

## Shared scientific stage checkpoint (2026-10-04)

The public HomeView and controller contracts now use the immutable ScienceLabUI stage. Two-finger observation is bounded 1–3×; the single-finger time probe observes already revealed data. This is a global mean temperature anomaly teaching model with an explicit finite eight-year record, a shared baseline/scenario axis, SI heat capacity and all2,921 points in a complete native PNG. See SCIENTIFIC_REVIEW.md for derivations, sources and limitations.

The actual app-hosted native run passed32 tests and produced39 reviewed PNGs. All original4 tests remain, while scientific cancellation energy, single-axis drawing, exact mounted image pixels, genuine QR decoding, controller pause and three-second removal lifetime are exercised. This checkpoint does not imply production host/window/permission/share or full localization acceptance. Native proofs and all retained failed-run evidence are recorded in Documentation/NATIVE_VERIFICATION_20261004.json.
