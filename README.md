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

- Product compatibility baseline: iOS 13+
- Interactive HomeView implementation target: iOS 15+
