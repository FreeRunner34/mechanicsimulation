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
2. Enroll/select the Apple Developer Team and configure signing.
3. Create/configure the StoreKit subscription in App Store Connect using `com.freerunner34.mastermechanic.pro.monthly`, then switch from local StoreKit testing to the App Store sandbox for final purchase validation.
4. Complete the App Privacy questionnaire so it matches the shipping binary. The current native build has no ads, tracking, Base44 SDK, analytics SDK, or app-level account.
5. Add screenshots, description, age rating and the remaining App Store Connect metadata. Public privacy and support pages are already present in this repository.

## Content migration status

The native catalog includes all 80 RepairCase records migrated from the original Base44 database, plus native advanced cases across the complete difficulty ladder. Imported cases preserve each repair order's vehicle, mileage, complaint, writer notes, verified root cause, and repair while repeated Base44 case families use shared native diagnostic-test templates. The ASE-style practice bank now contains at least five questions in each A1–A8 area.

## Architecture

- `MasterMechanicApp.swift` — app entry point and shared state
- `Models.swift` — simulator, repair-order and training models
- `AppData.swift` — local progression plus bundled simulator/training content
- `PurchaseManager.swift` — StoreKit 2 purchase + restore + entitlement state
- `Views.swift` — native SwiftUI presentation and simulator flow
- `PrivacyInfo.xcprivacy` — privacy manifest / required-reason API declaration

## Product direction

The native presentation intentionally moves away from the Base44 page/card feel. The main interaction is an iPhone-first diagnostic bay: the repair order opens like a work order, the bay is divided into real technician viewpoints, tools are selected from a tool cart, and evidence appears only after a valid test is run. Diagnosis and repair are separate calls so a user can identify the fault yet still make the wrong repair decision, preserving the comeback mechanic that makes the simulator useful.
