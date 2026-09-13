# MasterMechanic — Native iOS Diagnostic Simulator

This repository is the native iOS replacement for the original Base44 **Master Mechanic Diagnostic Pro** web app.

## Native feature set

- Rebuilt in **SwiftUI** as a native iPhone app. There is no web wrapper and no Base44 runtime dependency.
- Core simulator progress is stored on-device; no MasterMechanic login is required.
- The Base44/Stripe digital Pro unlock has been replaced with **StoreKit 2**.
- Added an Apple privacy manifest, including the `UserDefaults` required-reason declaration used by the app.
- Preserved the diagnostic loop: repair order → bay view → tool selection → evidence → root cause → repair → scored result.
- Preserved the six-level progression model from Entry Level through Diagnostic Specialist.
- Added **Dealer Mode** for the five fictional manufacturers, with brand-locked case rotation across the full difficulty ladder.
- Added an **RO Library** with search, difficulty filters, attempt counts, best scores, and replay.
- Added **career stats and achievements** including XP, accuracy, streaks, comebacks, difficulty performance, recent ROs, and the achievement catalog.
- Replays are tracked but do not inflate career XP, completed-case counts, accuracy, or streaks.
- Expanded ASE-style practice to at least five questions in every A1–A8 area, with immediate answer feedback and explanations.
- Vehicle brands are fictional to avoid presenting the simulator as an official OEM product.

## Content migration

The native catalog includes all **80 RepairCase records** migrated from the original Base44 database, plus native advanced cases across the complete difficulty ladder. Imported cases preserve each repair order's vehicle, mileage, complaint, writer notes, verified root cause, and repair. Repeated Base44 case families use shared native diagnostic-test templates so the content works completely offline.

The migrated catalog is validated automatically in CI for row count, required fields, valid difficulties, and unique IDs.

## Local development

1. Clone/download this repo on the Mac.
2. Open `MasterMechanic.xcodeproj` in Xcode.
3. Select the shared **MasterMechanic** scheme.
4. Pick an iPhone simulator and Run.

The project targets **iOS 17+** and has no third-party package dependencies.

A paid Apple Developer Program membership is not required for the simulator workflow or the local StoreKit test configuration. Signing with a distribution team is part of the later App Store phase.

## StoreKit testing before App Store Connect

The project includes `MasterMechanic/MasterMechanic.storekit` with a local monthly Pro subscription matching the production product ID:

`com.freerunner34.mastermechanic.pro.monthly`

The shared Xcode scheme uses this configuration for local StoreKit testing. The code supports product loading, verified purchases, transaction updates, entitlement refresh, expiration/revocation handling, and restore purchases.

The UI does not hard-code a storefront price. When connected to the App Store, it displays the localized price supplied by StoreKit.

Before distribution, create the corresponding auto-renewable subscription in App Store Connect. Do not add Stripe or another external checkout for the in-app Pro feature unlock.

## Automated verification

The repository contains an XCTest target and automated project preflight checks. CI is configured to:

- validate the imported repair-order catalog and production configuration;
- build the app in **Debug** and **Release** using Xcode 26 on macOS 26;
- run native unit tests on an iPhone simulator, including catalog integrity, case rotation, Dealer Mode, replay progression rules, scoring/progress behavior, training-bank coverage, production URLs, and local StoreKit configuration.

## Privacy and support

- `PRIVACY.md` is the public privacy policy used by the app.
- `SUPPORT.md` is the public support page used by the app.
- The shipping native code does not include Base44, Stripe, advertising SDKs, third-party analytics SDKs, cross-app tracking, or a MasterMechanic user account.
- Simulator progress remains local to the device.

## Remaining Apple/distribution work

The engineering work that can be completed independently of the Apple Developer Program is essentially finished. The remaining distribution phase is developer/account owned:

1. Add the final **1024 × 1024 App Store icon** to `Assets.xcassets/AppIcon.appiconset`.
2. Enroll/select the Apple Developer Team and configure signing/capabilities.
3. Create the App Store Connect app record and the subscription product `com.freerunner34.mastermechanic.pro.monthly`.
4. Validate the real product using Apple's sandbox/TestFlight environment.
5. Complete App Privacy and age-rating questionnaires.
6. Add App Store screenshots, description, keywords, support/privacy metadata, pricing/availability, and other listing information.
7. Archive, upload, TestFlight-test, and submit the release for App Review.

## Architecture

- `MasterMechanicApp.swift` — app entry point and shared state
- `Models.swift` — simulator, repair-order, case rotation, Dealer Mode, and training models
- `AppData.swift` — local progression, history, achievements, and bundled simulator/training content
- `ImportedBase44Cases.swift` — offline migrated Base44 repair-order catalog
- `ExtraASEQuestions.swift` — expanded A1–A8 training bank
- `PurchaseManager.swift` — StoreKit 2 purchase, restore, transaction updates, and entitlement state
- `Views.swift` — native SwiftUI presentation, simulator, Dealer Mode, library, stats, achievements, and training flow
- `MasterMechanic.storekit` — local StoreKit configuration
- `PrivacyInfo.xcprivacy` — Apple privacy manifest / required-reason API declaration
- `MasterMechanicTests` — native unit and local StoreKit tests

## Product direction

The native presentation intentionally moves away from the Base44 page/card feel. The main interaction is an iPhone-first diagnostic bay: the repair order opens like a work order, the bay is divided into technician viewpoints, tools are selected from a tool cart, and evidence appears only after a valid test is run. Diagnosis and repair remain separate calls so a user can identify the fault yet still make the wrong repair decision, preserving the comeback mechanic that makes the simulator useful.
