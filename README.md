# MasterMechanic — Native iOS Diagnostic Simulator

This repository is the native iOS replacement for the original Base44 **Master Mechanic Diagnostic Pro** web app.

## What changed

- Rebuilt in **SwiftUI** as a native iPhone app. There is no web wrapper and no Base44 runtime dependency.
- Core simulator progress is stored on-device; no MasterMechanic login is required.
- The Base44/Stripe digital Pro unlock has been replaced with **StoreKit 2**.
- Added an Apple privacy manifest, including the approved `UserDefaults` required-reason declaration.
- Preserved the diagnostic loop: repair order → bay view → tool selection → evidence → root cause → repair → scored result.
- Preserved the six-level progression model and independent ASE-style practice section.
- Vehicle brands are fictional to avoid presenting the simulator as an official OEM product.

## Open it

1. Clone/download this repo on the Mac.
2. Open `MasterMechanic.xcodeproj` in Xcode.
3. In **Signing & Capabilities**, choose your Apple Developer Team.
4. Pick an iPhone simulator or a paired iPhone and Run.

The project targets **iOS 17+** and has no third-party package dependencies.

## StoreKit setup before App Store submission

The app expects this subscription product ID:

`com.freerunner34.mastermechanic.pro.monthly`

Create that auto-renewable subscription in App Store Connect and set the price to the tier you want (the prior Base44 app used $6.99/month). The UI reads the localized price directly from StoreKit when the product exists.

Do not add Stripe or an external checkout for the in-app Pro feature unlock.

## Required finishing items before archive/submission

The native application architecture is in place, but Apple requires developer-owned metadata/assets that cannot be safely guessed:

1. Add the final **1024 × 1024 App Store icon** to `Assets.xcassets/AppIcon.appiconset`.
2. Replace the placeholder privacy URL in `AppConfig.privacyURL` with your published privacy-policy page and use the same URL in App Store Connect.
3. Create/configure the StoreKit subscription in App Store Connect and submit it with the first app version.
4. Set your Apple Developer Team/signing certificate in Xcode.
5. Complete the App Privacy questionnaire so it matches the shipping binary. The current native build has no ads, tracking, Base44 SDK, analytics SDK, or app-level account.
6. Add screenshots, description, support URL, age rating and other App Store Connect metadata.

## Content migration status

The repo contains a native case engine plus representative cases from the original live Base44 app across the complete difficulty ladder. It also contains an initial ASE-style bank across A1–A8. The original Base44 database currently contains substantially more generated cases/questions; those can be converted into bundled native content without changing this architecture.

## Architecture

- `MasterMechanicApp.swift` — app entry point and shared state
- `Models.swift` — simulator, repair-order and training models
- `AppData.swift` — local progression plus bundled simulator/training content
- `PurchaseManager.swift` — StoreKit 2 purchase + restore + entitlement state
- `Views.swift` — native SwiftUI presentation and simulator flow
- `PrivacyInfo.xcprivacy` — privacy manifest / required-reason API declaration

## Product direction

The native presentation intentionally moves away from the Base44 page/card feel. The main interaction is an iPhone-first diagnostic bay: the repair order opens like a work order, the bay is divided into real technician viewpoints, tools are selected from a tool cart, and evidence appears only after a valid test is run. Diagnosis and repair are separate calls so a user can identify the fault yet still make the wrong repair decision, preserving the comeback mechanic that makes the simulator useful.
