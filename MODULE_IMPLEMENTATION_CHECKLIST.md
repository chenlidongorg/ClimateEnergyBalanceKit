# SPM Implementation Checklist

Use this checklist before coding starts and before each public tag release.

## A. Package Identity
- [ ] Repository name == package product name == module import name
- [ ] Stable identifier exists (reverse-domain style)
- [ ] Product compatibility baseline is documented as iOS 13
- [ ] `Package.swift` platform is `.iOS(.v15)` by default, or approved `.iOS(.v16)` with downgrade notes

## B. Metadata Self-Management
- [ ] `ModuleInfo.metadata` is public and directly readable without UI mount
- [ ] Metadata contains `title/subtitle/logo/category/minimumIOSVersion`
- [ ] Localized keys exist: `module.title`, `module.subtitle`
- [ ] `logo` fallback chain works: `logo` -> system placeholder

## C. Public Entry and Output
- [ ] `HomeView` public init includes `headerStyle/qrcode/onCapture/onEvent/controller`
- [ ] Export image goes through `onCapture?(UIImage)` only (no direct photo-save in kit)
- [ ] Capture button has success feedback (`checkmark`) and auto-resets to camera icon
- [ ] Event output includes required minimum lifecycle/interaction/business/error events
- [ ] ControlBar icon mapping follows standard symbols (`arrow.triangle.2.circlepath`, `camera.shutter.button.fill`/`photo.artframe`, `gearshape.fill`, `play`, `pause`)
- [ ] ControlBar keeps fixed left-center-right semantic layout
- [ ] ControlBar action buttons are icon-only and include localized accessibility labels
- [ ] `play/pause` semantics represent continuous run toggle (not single-step run)
- [ ] Exposed parameters produce observable result changes
- [ ] High-frequency parameters stay on main screen; low-frequency parameters go to gear/settings sheet
- [ ] Main viewport prioritizes visualization area over rarely changed controls

## D. External Control
- [ ] `ModuleController` supports `reset/applyPreset/setParameter`
- [ ] Unsupported command is safe and emits `unsupported_command`

## E. External Consumption (Public-ready)
- [ ] README includes SwiftPM add steps (URL + tag)
- [ ] README includes metadata read example (`ModuleInfo.metadata`)
- [ ] README includes event callback example (`onEvent`)
- [ ] README includes control example (`ModuleController`)

## F. Build and Quality
- [ ] Build passes on iOS device (`arm64`)
- [ ] Build passes on iOS simulator (`arm64`, `x86_64`)
- [ ] Localization MVP minimum exists: `en`, `zh-Hans`
- [ ] No app-private dependency leaks into public package

## G. Mandatory Cascade Package Update Flow
- [ ] Bottom SPM push is immediately followed by `FunyBoxKit` dependency resolve + lock refresh
- [ ] `FunyBoxKit` push is immediately followed by App dependency resolve + lock refresh
- [ ] App `Package.resolved` has latest `funyboxkit` and bottom-kit transitive revisions
- [ ] No manual package update is required from product owner

## H. Localization Rollout Gate
- [ ] Full localization is not started before explicit command: `支持完整语言`
- [ ] After `支持完整语言`, language set matches FunyBoxKit baseline (case-insensitive language-code check)
- [ ] After `支持完整语言`, all required localization keys are complete across all target languages
- [ ] After `支持完整语言`, non-English locale files are translated into the target language (not English placeholders)
