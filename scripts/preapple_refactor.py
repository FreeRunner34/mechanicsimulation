from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"Expected exactly one match in {path} but found {count}: {old[:80]!r}")
    path.write_text(text.replace(old, new, 1))


# 1) Make imported repair orders explicit and replace placeholder production URLs.
models = ROOT / "MasterMechanic" / "Models.swift"
replace_once(
    models,
    '    static let privacyURL = URL(string: "https://example.com/mastermechanic/privacy")!\n    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!',
    '    static let privacyURL = URL(string: "https://github.com/FreeRunner34/mechanicsimulation/blob/main/PRIVACY.md")!\n    static let supportURL = URL(string: "https://github.com/FreeRunner34/mechanicsimulation/blob/main/SUPPORT.md")!\n    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!'
)
replace_once(
    models,
    '    var playableCases: [DiagnosticCase] {\n        cases + Self.additionalCases(using: tools)\n    }',
    '    var playableCases: [DiagnosticCase] {\n        let native = cases + Self.additionalCases(using: tools)\n        let existingIDs = Set(native.map(\\.id))\n        return native + ImportedBase44Cases.load().filter { !existingIDs.contains($0.id) }\n    }'
)


# 2) Expand the ASE-style training bank without touching the original eight seed questions.
extra_ase = r'''import Foundation

enum ExtraASEQuestions {
    static let all: [ASEQuestion] = [
        // A1 — Engine Repair
        q("a1x1", "A1", "A cylinder has low compression. A cylinder-leakage test sends most of the air into the crankcase. What is most likely?", "C", "Burned exhaust valve", "Blown head gasket between cylinders", "Worn or damaged piston rings", "Restricted injector", "Air heard primarily in the crankcase indicates leakage past the piston and rings."),
        q("a1x2", "A1", "Oil pressure is low at hot idle but returns near specification when engine speed is increased. Which fault is most likely?", "B", "Stuck-closed thermostat", "Excessive bearing clearance", "Restricted air filter", "Open injector circuit", "Excessive internal clearance can bleed off oil pressure most noticeably at low pump speed."),
        q("a1x3", "A1", "An engine has a steady vacuum reading that drops sharply at regular intervals. What should be suspected first?", "A", "A valve that is not sealing consistently", "An overcharged A/C system", "A weak battery", "A slipping clutch", "A regular vacuum drop points toward a repeating cylinder sealing event such as a valve problem."),
        q("a1x4", "A1", "After cylinder-head replacement, an overhead-cam engine cranks unusually fast and has very low compression on all cylinders. What should be checked first?", "D", "Fuel pressure", "EVAP purge flow", "Alternator output", "Camshaft timing", "Incorrect cam timing can reduce effective compression across all cylinders and produce a fast-crank sound."),

        // A2 — Automatic Transmission / Transaxle
        q("a2x1", "A2", "An automatic transmission has delayed engagement only after sitting overnight. Fluid level is correct and there are no external leaks. What is a likely cause?", "A", "Internal drainback or an apply-circuit leak", "A stuck-open thermostat", "A weak ignition coil", "Incorrect wheel alignment", "A circuit that drains back can require time to refill after a long soak before a clutch applies."),
        q("a2x2", "A2", "During a road test, commanded gear and actual gear remain matched, but engine RPM flares during a torque-converter clutch apply event. What should be evaluated?", "C", "Wheel bearing preload", "Fuel tank venting", "Torque-converter clutch slip", "Camber angle", "RPM flare specifically during TCC apply points to converter-clutch holding performance."),
        q("a2x3", "A2", "A transmission shifts normally cold but develops harsh shifts after reaching operating temperature. Line pressure is higher than commanded when hot. What is the best next step?", "B", "Replace the engine mounts", "Diagnose pressure-control operation and the valve-body circuit", "Replace the battery", "Balance the tires", "Actual pressure that disagrees with commanded pressure directs diagnosis toward pressure control rather than unrelated systems."),
        q("a2x4", "A2", "After transmission service, the unit slips immediately in several ranges. The fluid level is correct, but the fluid installed does not meet the required specification. What should be done first?", "D", "Replace the torque converter", "Replace the TCM", "Perform an alignment", "Correct the fluid type and follow the specified service procedure", "Transmission friction and hydraulic behavior depend on using the specified fluid before deeper faults are condemned."),

        // A3 — Manual Drivetrain & Axles
        q("a3x1", "A3", "A manual-transmission vehicle creeps forward with the clutch pedal fully depressed, and reverse grinds when selected. What is most likely?", "B", "Wheel imbalance", "Clutch not fully releasing", "Open EVAP vent", "Low engine compression", "Creep and reverse grind indicate the input shaft is still being driven with the clutch pedal down."),
        q("a3x2", "A3", "A front-wheel-drive vehicle has a vibration during acceleration that disappears on coast. Which component should be inspected closely?", "C", "Cabin air filter", "Outer tie-rod end only", "Inner CV joint", "Thermostat housing", "Inner CV joint wear often produces load-sensitive acceleration vibration rather than the classic turning click of an outer joint."),
        q("a3x3", "A3", "A rear-wheel-drive vehicle has a clunk when changing from drive to reverse. Excessive rotational play is measured at the driveshaft before the differential input moves. What should be suspected?", "A", "Worn driveshaft/U-joint or slip-joint components", "Low refrigerant", "Restricted injector", "Faulty oxygen sensor", "Measured driveline lash ahead of the differential directs attention to the driveshaft joints and slip connection."),
        q("a3x4", "A3", "A manual transmission jumps out of one gear on deceleration but stays in all other gears. External linkage is adjusted correctly. What is most likely?", "D", "A weak battery", "A bad wheel-speed sensor", "A clogged fuel filter", "Internal wear in that gear's engagement components", "A problem isolated to one gear after external adjustment is verified points to internal engagement wear."),

        // A4 — Suspension & Steering
        q("a4x1", "A4", "A vehicle pulls right only while braking. Tire pressures and alignment are correct. What should be checked next?", "B", "EVAP purge flow", "Left/right brake force and caliper operation", "Fuel trim", "Battery state of charge", "A pull that occurs only during braking is more likely a brake-force imbalance than a static alignment issue."),
        q("a4x2", "A4", "The steering wheel does not return toward center after a turn. Front alignment shows insufficient positive caster. Which symptom is consistent with this reading?", "A", "Poor steering returnability", "Brake pedal pulsation", "Rich fuel trim", "A/C icing", "Positive caster contributes to directional stability and steering-wheel return after a turn."),
        q("a4x3", "A4", "A strut-equipped vehicle has a knocking noise over small bumps. The noise can be reproduced by turning the steering wheel while stationary, and movement is visible at the upper strut mount. What is most likely?", "C", "Wheel imbalance", "Rear axle ratio", "Worn upper strut mount/bearing", "Low fuel pressure", "Visible movement and noise at the upper mount under steering load isolates the mount/bearing assembly."),
        q("a4x4", "A4", "One front tire has feathered tread blocks across the surface. Which alignment angle is most directly associated with this wear pattern?", "D", "Caster only", "Ride height only", "Camber only", "Toe", "Incorrect toe scrubs the tread laterally and commonly produces a feathered feel across the tire."),

        // A5 — Brakes
        q("a5x1", "A5", "A brake pedal is firm with the engine off but drops slightly and feels normal when the engine starts. What does this indicate?", "A", "Brake booster assist is operating", "The master cylinder is bypassing", "The ABS pump has failed", "There is necessarily air in the system", "A small pedal drop when vacuum assist becomes available is a normal indication that the booster is providing assist."),
        q("a5x2", "A5", "A vehicle has a brake pulsation only during high-speed stops. Rotor thickness variation is above specification. What repair direction is appropriate?", "C", "Replace the battery", "Adjust caster", "Correct the rotor condition and inspect the causes of uneven rotor thickness", "Replace the fuel pump", "Thickness variation changes braking torque as the rotor rotates and is a direct cause of pedal pulsation."),
        q("a5x3", "A5", "One wheel remains partially applied after the brake pedal is released. Opening that caliper's bleeder frees the wheel immediately. What does this prove?", "B", "The wheel bearing is seized", "Hydraulic pressure is being trapped upstream of the caliper", "The tire is out of balance", "The ABS warning lamp is defective", "If opening the bleeder releases the brake, pressure was trapped in the hydraulic circuit rather than a purely mechanical bind."),
        q("a5x4", "A5", "ABS activates at 3 mph on a dry stop with no wheel lockup. Live data shows one wheel-speed signal dropping to zero early. What is the best diagnostic direction?", "D", "Replace the master cylinder", "Bleed all brakes first", "Replace all four sensors", "Inspect that wheel's sensor, encoder, air gap, and circuit", "A single implausible low-speed signal should be proven at that wheel before other ABS components are replaced."),

        // A6 — Electrical / Electronic Systems
        q("a6x1", "A6", "Battery voltage is 12.6 V at rest, but the starter clicks and a 2.1 V drop is measured from the negative battery post to the engine block while cranking. What is the fault direction?", "C", "Fuel pressure is low", "The alternator is overcharging", "Excessive resistance in the ground side of the starting circuit", "The immobilizer key is necessarily bad", "A large loaded voltage drop on the ground path proves excessive resistance there even when static battery voltage is normal."),
        q("a6x2", "A6", "A CAN network measures approximately 120 ohms with the network asleep when about 60 ohms is expected. What does this suggest?", "A", "One terminating resistor or its circuit may be open", "Both terminators are shorted together", "The battery is fully charged", "The fuel pump is restricted", "Two 120-ohm terminators in parallel produce about 60 ohms; about 120 ohms suggests one termination path is missing."),
        q("a6x3", "A6", "Several unrelated 5-volt sensors set circuit-low codes at exactly the same time. What should be checked before replacing sensors?", "B", "Tire pressure", "The shared 5-volt reference and ground circuits", "Cabin filter restriction", "Brake rotor runout", "Simultaneous faults on unrelated sensors often point to a common reference or ground circuit."),
        q("a6x4", "A6", "A fuse blows immediately whenever a circuit is powered. What is the safest diagnostic approach?", "D", "Install a larger fuse", "Bypass the fuse", "Replace every component on the circuit", "Isolate branches and locate the short using a current-limited test method", "A repeatedly blown fuse indicates excessive current; branch isolation and current limitation protect the harness while locating the short."),

        // A7 — Heating & Air Conditioning
        q("a7x1", "A7", "A/C low-side pressure is high and high-side pressure is low while vent temperature is warm. Compressor command is present. What condition is most likely?", "B", "Overcharged system", "Compressor not producing adequate pressure differential", "Restricted condenser airflow causing very high head pressure", "Heater core restriction", "High low-side with low high-side means the compressor is not creating the expected pressure difference."),
        q("a7x2", "A7", "A/C is cold at highway speed but warm at idle. High-side pressure rises sharply at idle and condenser airflow is weak. What should be inspected first?", "A", "Condenser fan operation and airflow", "Engine compression", "Transmission fluid", "Wheel alignment", "Poor condenser airflow is most critical at idle because ram air is absent, causing high head pressure and poor cooling."),
        q("a7x3", "A7", "Both heater hoses are hot, blower speed is normal, but discharge air stays cold when full heat is selected. What is the most likely system area?", "C", "Refrigerant charge", "Engine oil pressure", "Temperature blend-door/air-mix control", "Fuel delivery", "Hot heater hoses show the core is receiving heat, so the air-mix system becomes the primary direction."),
        q("a7x4", "A7", "An evaporator freezes after extended operation. The blower continues to run but airflow from the vents drops greatly. What should be evaluated?", "D", "Differential backlash", "Brake fluid moisture", "Battery cable resistance", "Evaporator temperature sensing/control and airflow through the evaporator", "Evaporator icing restricts airflow and can result from incorrect temperature control or insufficient airflow across the core."),

        // A8 — Engine Performance
        q("a8x1", "A8", "Long-term fuel trim is +22% at idle but drops near 0% at 2500 rpm with no load. What is most likely?", "A", "A vacuum leak that has the greatest effect at idle", "A restricted exhaust", "An overcharging alternator", "A slipping clutch", "Unmetered air has its largest percentage effect at low airflow, so trims often improve as engine speed and airflow increase."),
        q("a8x2", "A8", "A misfire counter increases only on cylinder 2. Swapping the ignition coil from cylinder 2 to cylinder 4 causes the misfire to move to cylinder 4. What has been proven?", "C", "Cylinder 2 has low compression", "The fuel pump is weak", "The moved ignition coil is faulty", "The catalytic converter is restricted", "A fault that follows a component during a controlled swap directly implicates that component."),
        q("a8x3", "A8", "Commanded fuel pressure stays high during a loaded acceleration, but actual fuel pressure falls and the engine goes lean. What should be diagnosed?", "B", "Wheel alignment", "Fuel-delivery ability under load", "A/C blend door", "Brake booster vacuum only", "When actual fuel pressure cannot follow commanded pressure under demand, supply capacity or pressure control needs diagnosis."),
        q("a8x4", "A8", "An oxygen sensor ahead of the catalyst switches normally, but the downstream sensor closely mirrors the upstream sensor after the catalyst is hot. What does this pattern suggest?", "D", "A perfect catalyst", "A weak battery", "A stuck thermostat only", "Low catalyst oxygen-storage efficiency", "A healthy catalyst dampens downstream oxygen switching; a downstream pattern that closely follows upstream suggests reduced catalyst efficiency.")
    ]

    private static func q(_ id: String, _ area: String, _ question: String, _ correct: String, _ a: String, _ b: String, _ c: String, _ d: String, _ explanation: String) -> ASEQuestion {
        ASEQuestion(
            id: id,
            area: area,
            question: question,
            choices: [
                ASEChoice(id: "A", text: a),
                ASEChoice(id: "B", text: b),
                ASEChoice(id: "C", text: c),
                ASEChoice(id: "D", text: d)
            ],
            correctID: correct,
            explanation: explanation
        )
    }
}

extension AppData {
    var trainingQuestions: [ASEQuestion] {
        aseQuestions + ExtraASEQuestions.all
    }
}
'''
(ROOT / "MasterMechanic" / "ExtraASEQuestions.swift").write_text(extra_ase)


# 3) Strengthen StoreKit 2 handling and remove any hard-coded storefront price.
purchase_manager = r'''import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var isPro = false
    @Published private(set) var isLoadingProduct = false
    @Published var message: String?

    private var transactionTask: Task<Void, Never>?

    func prepare() async {
        startTransactionListenerIfNeeded()
        await refreshEntitlements()
        await loadProduct()
    }

    func loadProduct() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            product = try await Product.products(for: [AppConfig.proProductID]).first
            if product == nil {
                message = "Pro purchase information is not available in this store yet."
            }
        } catch {
            product = nil
            message = "Pro purchase information is unavailable right now."
        }
    }

    func buyPro() async {
        guard let product else {
            message = "Pro is not available from the App Store right now."
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .pending:
                message = "The purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = isPro ? "Pro access restored." : "No active Pro subscription was found."
        } catch {
            message = "Restore failed: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var active = false
        let now = Date()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == AppConfig.proProductID,
                  transaction.revocationDate == nil else { continue }

            if let expiration = transaction.expirationDate {
                if expiration > now { active = true }
            } else {
                active = true
            }
        }

        isPro = active
    }

    private func startTransactionListenerIfNeeded() {
        guard transactionTask == nil else { return }
        transactionTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = result else { continue }

                if transaction.productID == AppConfig.proProductID {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw PurchaseError.failedVerification
        }
    }

    deinit { transactionTask?.cancel() }

    enum PurchaseError: Error {
        case failedVerification
    }
}
'''
(ROOT / "MasterMechanic" / "PurchaseManager.swift").write_text(purchase_manager)


# 4) Local StoreKit configuration for testing before App Store Connect exists.
storekit = r'''{
  "identifier" : "MMLOCAL1",
  "nonRenewingSubscriptions" : [
  ],
  "products" : [
  ],
  "settings" : {
  },
  "subscriptionGroups" : [
    {
      "id" : "MMGROUP1",
      "localizations" : [
      ],
      "name" : "MasterMechanic Pro",
      "subscriptions" : [
        {
          "adHocOffers" : [
          ],
          "codeOffers" : [
          ],
          "displayPrice" : "6.99",
          "familyShareable" : false,
          "groupNumber" : 1,
          "internalID" : "MMPRO001",
          "introductoryOffer" : null,
          "localizations" : [
            {
              "description" : "Unlock the advanced diagnostic ladder and Pro repair-order catalog.",
              "displayName" : "MasterMechanic Pro Monthly",
              "locale" : "en_US"
            }
          ],
          "productID" : "com.freerunner34.mastermechanic.pro.monthly",
          "recurringSubscriptionPeriod" : "P1M",
          "referenceName" : "MasterMechanic Pro Monthly",
          "subscriptionGroupID" : "MMGROUP1",
          "type" : "RecurringSubscription"
        }
      ]
    }
  ],
  "version" : {
    "major" : 2,
    "minor" : 0
  }
}
'''
(ROOT / "MasterMechanic" / "MasterMechanic.storekit").write_text(storekit)


# 5) Production-facing policy/support pages that are publicly reachable from the repository.
privacy = r'''# MasterMechanic Privacy Policy

**Effective date: September 13, 2026**

MasterMechanic is an independent automotive diagnostic training simulator.

## Information the app stores

MasterMechanic does not require a user account. Simulator progress, scores, streaks, achievements, and recent repair-order history are stored locally on the device using Apple platform storage.

## Purchases

If you purchase MasterMechanic Pro, Apple processes the transaction through the App Store. The app receives StoreKit transaction and entitlement information needed to determine whether Pro access is active. MasterMechanic does not receive or store your full payment-card information.

## Tracking, advertising, and analytics

The native iOS app does not include third-party advertising SDKs, third-party analytics SDKs, cross-app tracking, Base44, or Stripe. MasterMechanic does not sell personal information.

## Data sharing

The app does not transmit simulator progress to a MasterMechanic server. Apple may process App Store and StoreKit information under Apple's own terms and privacy policies.

## Data deletion

Because gameplay progress is stored locally and no MasterMechanic account is created, you can remove local gameplay data from the app's **Profile > Reset local progress** control or by deleting the app from the device.

## Children

MasterMechanic is an educational simulation and is not designed to collect personal information from children.

## Changes

If the app's data practices change, this policy and the App Store privacy disclosures will be updated before the changed version is distributed.

## Contact

For support or privacy questions, use the support page in this repository or open an issue at https://github.com/FreeRunner34/mechanicsimulation/issues.
'''
(ROOT / "PRIVACY.md").write_text(privacy)

support = r'''# MasterMechanic Support

MasterMechanic is an independent automotive diagnostic training simulator for iPhone.

## Before reporting a problem

1. Make sure you are running the newest available version of MasterMechanic.
2. If Pro access is missing after reinstalling, open **Profile** and choose **Restore purchases**.
3. If a repair order appears stuck, exit the repair order and start another case from the Simulator tab.
4. Do not rely on the simulator as a substitute for vehicle-specific service information, safety procedures, or professional repair documentation.

## Report a bug or request help

Open a support issue at:
https://github.com/FreeRunner34/mechanicsimulation/issues

When reporting a bug, include the iPhone model, iOS version, app version, what you were doing, what you expected to happen, and what actually happened. Do not post private payment information.

## Purchases

Purchases and subscriptions are processed by Apple. MasterMechanic includes a **Restore purchases** control in the Profile screen. Apple subscription management is available from the device's Apple ID subscription settings.
'''
(ROOT / "SUPPORT.md").write_text(support)


# 6) Update user-facing StoreKit/support/privacy presentation and use the expanded question bank.
views = ROOT / "MasterMechanic" / "Views.swift"
replace_once(
    views,
    'questions:AppData.shared.aseQuestions.filter{$0.area==area.0}.shuffled()',
    'questions:AppData.shared.trainingQuestions.filter{$0.area==area.0}.shuffled()'
)
replace_once(
    views,
    'Section("PRIVACY & SUPPORT"){NavigationLink("Privacy"){PrivacyView()};Link("Manage Apple subscription",destination:URL(string:"https://apps.apple.com/account/subscriptions")!);Text("No MasterMechanic account is required. Progress is stored on this device.").font(.footnote).foregroundStyle(.secondary)}',
    'Section("PRIVACY & SUPPORT"){NavigationLink("Privacy"){PrivacyView()};Link("Support",destination:AppConfig.supportURL);Link("Manage Apple subscription",destination:URL(string:"https://apps.apple.com/account/subscriptions")!);Text("No MasterMechanic account is required. Progress is stored on this device.").font(.footnote).foregroundStyle(.secondary)}'
)
replace_once(
    views,
    'Text(purchases.product.map{"\\($0.displayPrice) / month"} ?? "$6.99 / month").font(.title2.bold())',
    'Group{if let product=purchases.product{Text("\\(product.displayPrice) / month").font(.title2.bold())}else if purchases.isLoadingProduct{ProgressView("Loading App Store price…")}else{Text("App Store price unavailable").font(.headline).foregroundStyle(.secondary)}}'
)
replace_once(
    views,
    'Button(purchases.isPro ? "Pro is active":"Start Pro"){Task{await purchases.buyPro()}}.buttonStyle(PrimaryButtonStyle()).disabled(purchases.isPro)',
    'Button(purchases.isPro ? "Pro is active":(purchases.product == nil ? "Pro unavailable":"Start Pro")){Task{await purchases.buyPro()}}.buttonStyle(PrimaryButtonStyle()).disabled(purchases.isPro || purchases.product == nil)'
)
replace_once(
    views,
    'HStack(spacing:18){NavigationLink("Privacy policy"){PrivacyView()};Link("Terms of Use",destination:AppConfig.termsURL)}.font(.footnote)',
    'HStack(spacing:18){NavigationLink("Privacy policy"){PrivacyView()};Link("Support",destination:AppConfig.supportURL);Link("Terms of Use",destination:AppConfig.termsURL)}.font(.footnote)'
)
replace_once(
    views,
    'Text("Before App Store submission, replace the placeholder privacy URL in AppConfig with your published policy and make the App Privacy answers match the shipping build.")',
    'Text("MasterMechanic does not sell personal information. Local simulator progress can be removed from Profile by resetting local progress or by deleting the app.")'
)


# 7) Add a real XCTest target and remove the global DiagnosticCase-array + overload hook.
tests_dir = ROOT / "MasterMechanicTests"
tests_dir.mkdir(exist_ok=True)
tests = r'''import XCTest
@testable import MasterMechanic

final class MasterMechanicTests: XCTestCase {
    func testImportedRepairOrderCountIsEighty() {
        XCTAssertEqual(ImportedBase44Cases.importedCount, 80)
    }

    func testPlayableCaseIDsAreUnique() {
        let ids = AppData.shared.playableCases.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testEveryDifficultyHasPlayableCases() {
        for difficulty in Difficulty.allCases {
            let count = AppData.shared.playableCases.filter { $0.difficulty == difficulty }.count
            XCTAssertGreaterThan(count, 0, "No playable cases for \(difficulty.rawValue)")
        }
    }

    func testEveryCaseHasAPlayableDiagnosticPath() {
        for diagnosticCase in AppData.shared.playableCases {
            XCTAssertFalse(diagnosticCase.repairOrder.vehicle.isEmpty)
            XCTAssertFalse(diagnosticCase.repairOrder.complaint.isEmpty)
            XCTAssertFalse(diagnosticCase.inspections.isEmpty)
            XCTAssertEqual(diagnosticCase.causes.filter(\.correct).count, 1, diagnosticCase.id)
            XCTAssertEqual(diagnosticCase.repairs.filter(\.correct).count, 1, diagnosticCase.id)

            let toolIDs = Set(diagnosticCase.tools.map(\.id))
            for inspection in diagnosticCase.inspections {
                XCTAssertTrue(toolIDs.contains(inspection.toolID), "\(diagnosticCase.id) is missing tool \(inspection.toolID)")
            }
        }
    }

    func testRecentCaseExclusionWorksWhenAlternativesExist() {
        for difficulty in Difficulty.allCases {
            let pool = AppData.shared.playableCases.filter { $0.difficulty == difficulty }
            guard pool.count > 1, let first = pool.first else { continue }
            for _ in 0..<25 {
                let next = AppData.shared.nextCase(difficulty: difficulty, excluding: [first.id])
                XCTAssertNotEqual(next?.id, first.id)
            }
        }
    }

    func testTrainingBankHasAtLeastFiveQuestionsPerArea() {
        for area in ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"] {
            XCTAssertGreaterThanOrEqual(AppData.shared.trainingQuestions.filter { $0.area == area }.count, 5, area)
        }
    }

    func testProductionURLsAreNotPlaceholders() {
        XCTAssertFalse(AppConfig.privacyURL.absoluteString.contains("example.com"))
        XCTAssertFalse(AppConfig.supportURL.absoluteString.contains("example.com"))
        XCTAssertEqual(AppConfig.proProductID, "com.freerunner34.mastermechanic.pro.monthly")
    }

    @MainActor
    func testProgressScoringPersistsExpectedXPAndCanReset() {
        let progress = ProgressStore()
        progress.reset()
        guard let diagnosticCase = AppData.shared.playableCases.first else {
            XCTFail("No playable case")
            return
        }

        let xp = progress.record(case: diagnosticCase, score: 80, solved: true, tests: 3, wastedTests: 0)
        let expected = Int((80.0 * diagnosticCase.difficulty.multiplier * 5.0).rounded())
        XCTAssertEqual(xp, expected)
        XCTAssertEqual(progress.points, expected)
        XCTAssertEqual(progress.completedCases, 1)
        XCTAssertEqual(progress.correctCases, 1)
        XCTAssertEqual(progress.streak, 1)

        progress.reset()
        XCTAssertEqual(progress.points, 0)
        XCTAssertEqual(progress.completedCases, 0)
        XCTAssertTrue(progress.history.isEmpty)
    }
}
'''
(tests_dir / "MasterMechanicTests.swift").write_text(tests)

# Shared scheme activates local StoreKit for Run and includes the unit-test target.
scheme_dir = ROOT / "MasterMechanic.xcodeproj" / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
scheme = r'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "E10000000000000000000001"
               BuildableName = "MasterMechanic.app"
               BlueprintName = "MasterMechanic"
               ReferencedContainer = "container:MasterMechanic.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "NO"
            buildForProfiling = "NO"
            buildForArchiving = "NO"
            buildForAnalyzing = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "E20000000000000000000001"
               BuildableName = "MasterMechanicTests.xctest"
               BlueprintName = "MasterMechanicTests"
               ReferencedContainer = "container:MasterMechanic.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "E20000000000000000000001"
               BuildableName = "MasterMechanicTests.xctest"
               BlueprintName = "MasterMechanicTests"
               ReferencedContainer = "container:MasterMechanic.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "E10000000000000000000001"
            BuildableName = "MasterMechanic.app"
            BlueprintName = "MasterMechanic"
            ReferencedContainer = "container:MasterMechanic.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
      <StoreKitConfigurationFileReference
         identifier = "../../../MasterMechanic/MasterMechanic.storekit">
      </StoreKitConfigurationFileReference>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "E10000000000000000000001"
            BuildableName = "MasterMechanic.app"
            BlueprintName = "MasterMechanic"
            ReferencedContainer = "container:MasterMechanic.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''
(scheme_dir / "MasterMechanic.xcscheme").write_text(scheme)


# 8) Xcode project wiring: test target, expanded training source, StoreKit config, and no ImportedCaseHook.
pbx = ROOT / "MasterMechanic.xcodeproj" / "project.pbxproj"
text = pbx.read_text()

def r(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"pbxproj replacement expected one match, found {count}: {old[:100]!r}")
    text = text.replace(old, new, 1)

r(
    '\t\tA10000000000000000000008 /* ImportedBase44Cases.swift in Sources */ = {isa = PBXBuildFile; fileRef = B1000000000000000000000A /* ImportedBase44Cases.swift */; };\n\t\tA10000000000000000000009 /* ImportedCaseHook.swift in Sources */ = {isa = PBXBuildFile; fileRef = B1000000000000000000000B /* ImportedCaseHook.swift */; };',
    '\t\tA10000000000000000000008 /* ImportedBase44Cases.swift in Sources */ = {isa = PBXBuildFile; fileRef = B1000000000000000000000A /* ImportedBase44Cases.swift */; };\n\t\tA1000000000000000000000A /* ExtraASEQuestions.swift in Sources */ = {isa = PBXBuildFile; fileRef = B1000000000000000000000C /* ExtraASEQuestions.swift */; };\n\t\tA20000000000000000000001 /* MasterMechanicTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = B20000000000000000000001 /* MasterMechanicTests.swift */; };'
)
r(
    '\t\tB1000000000000000000000A /* ImportedBase44Cases.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ImportedBase44Cases.swift; sourceTree = "<group>"; };\n\t\tB1000000000000000000000B /* ImportedCaseHook.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ImportedCaseHook.swift; sourceTree = "<group>"; };',
    '\t\tB1000000000000000000000A /* ImportedBase44Cases.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ImportedBase44Cases.swift; sourceTree = "<group>"; };\n\t\tB1000000000000000000000C /* ExtraASEQuestions.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ExtraASEQuestions.swift; sourceTree = "<group>"; };\n\t\tB1000000000000000000000D /* MasterMechanic.storekit */ = {isa = PBXFileReference; lastKnownFileType = text; path = MasterMechanic.storekit; sourceTree = "<group>"; };\n\t\tB20000000000000000000001 /* MasterMechanicTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MasterMechanicTests.swift; sourceTree = "<group>"; };\n\t\tB20000000000000000000002 /* MasterMechanicTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = MasterMechanicTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };'
)
r(
    '/* End PBXFileReference section */\n\n/* Begin PBXFrameworksBuildPhase section */',
    '''/* End PBXFileReference section */

/* Begin PBXContainerItemProxy section */
\t\tG20000000000000000000001 /* PBXContainerItemProxy */ = {
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = E10000000000000000000002 /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = E10000000000000000000001;
\t\t\tremoteInfo = MasterMechanic;
\t\t};
/* End PBXContainerItemProxy section */

/* Begin PBXFrameworksBuildPhase section */'''
)
r(
    '\t\tC10000000000000000000001 /* Frameworks */ = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = ();\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};',
    '\t\tC10000000000000000000001 /* Frameworks */ = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = ();\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n\t\tC20000000000000000000001 /* Frameworks */ = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = ();\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};'
)
r(
    '\t\t\tchildren = (\n\t\t\t\tD10000000000000000000002 /* MasterMechanic */,\n\t\t\t\tD10000000000000000000003 /* Products */,\n\t\t\t);',
    '\t\t\tchildren = (\n\t\t\t\tD10000000000000000000002 /* MasterMechanic */,\n\t\t\t\tD20000000000000000000001 /* MasterMechanicTests */,\n\t\t\t\tD10000000000000000000003 /* Products */,\n\t\t\t);'
)
r(
    '\t\t\t\tB1000000000000000000000A /* ImportedBase44Cases.swift */,\n\t\t\t\tB1000000000000000000000B /* ImportedCaseHook.swift */,\n\t\t\t\tB10000000000000000000004 /* PurchaseManager.swift */,',
    '\t\t\t\tB1000000000000000000000A /* ImportedBase44Cases.swift */,\n\t\t\t\tB1000000000000000000000C /* ExtraASEQuestions.swift */,\n\t\t\t\tB1000000000000000000000D /* MasterMechanic.storekit */,\n\t\t\t\tB10000000000000000000004 /* PurchaseManager.swift */,'
)
r(
    '\t\tD10000000000000000000003 /* Products */ = {',
    '''\t\tD20000000000000000000001 /* MasterMechanicTests */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tB20000000000000000000001 /* MasterMechanicTests.swift */,
\t\t\t);
\t\t\tpath = MasterMechanicTests;
\t\t\tsourceTree = "<group>";
\t\t};
\t\tD10000000000000000000003 /* Products */ = {'''
)
r(
    '\t\t\tchildren = (\n\t\t\t\tB10000000000000000000009 /* MasterMechanic.app */,\n\t\t\t);',
    '\t\t\tchildren = (\n\t\t\t\tB10000000000000000000009 /* MasterMechanic.app */,\n\t\t\t\tB20000000000000000000002 /* MasterMechanicTests.xctest */,\n\t\t\t);'
)
r(
    '/* End PBXNativeTarget section */',
    '''\t\tE20000000000000000000001 /* MasterMechanicTests */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = F20000000000000000000003 /* Build configuration list for PBXNativeTarget "MasterMechanicTests" */;
\t\t\tbuildPhases = (
\t\t\t\tC20000000000000000000002 /* Sources */,
\t\t\t\tC20000000000000000000001 /* Frameworks */,
\t\t\t\tC20000000000000000000003 /* Resources */,
\t\t\t);
\t\t\tbuildRules = ();
\t\t\tdependencies = (
\t\t\t\tH20000000000000000000001 /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = MasterMechanicTests;
\t\t\tproductName = MasterMechanicTests;
\t\t\tproductReference = B20000000000000000000002 /* MasterMechanicTests.xctest */;
\t\t\tproductType = "com.apple.product-type.bundle.unit-test";
\t\t};
/* End PBXNativeTarget section */'''
)
r(
    '\t\t\t\tTargetAttributes = {\n\t\t\t\t\tE10000000000000000000001 = { CreatedOnToolsVersion = 26.0; };\n\t\t\t\t};',
    '\t\t\t\tTargetAttributes = {\n\t\t\t\t\tE10000000000000000000001 = { CreatedOnToolsVersion = 26.0; };\n\t\t\t\t\tE20000000000000000000001 = { CreatedOnToolsVersion = 26.0; TestTargetID = E10000000000000000000001; };\n\t\t\t\t};'
)
r(
    '\t\t\ttargets = (E10000000000000000000001 /* MasterMechanic */);',
    '\t\t\ttargets = (E10000000000000000000001 /* MasterMechanic */, E20000000000000000000001 /* MasterMechanicTests */);'
)
r(
    '/* End PBXResourcesBuildPhase section */',
    '''\t\tC20000000000000000000003 /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = ();
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXResourcesBuildPhase section */'''
)
r(
    '\t\t\t\tA10000000000000000000008 /* ImportedBase44Cases.swift in Sources */,\n\t\t\t\tA10000000000000000000009 /* ImportedCaseHook.swift in Sources */,\n\t\t\t\tA10000000000000000000004 /* PurchaseManager.swift in Sources */,',
    '\t\t\t\tA10000000000000000000008 /* ImportedBase44Cases.swift in Sources */,\n\t\t\t\tA1000000000000000000000A /* ExtraASEQuestions.swift in Sources */,\n\t\t\t\tA10000000000000000000004 /* PurchaseManager.swift in Sources */,'
)
r(
    '/* End PBXSourcesBuildPhase section */',
    '''\t\tC20000000000000000000002 /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\tA20000000000000000000001 /* MasterMechanicTests.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXSourcesBuildPhase section */'''
)
r(
    '/* Begin XCBuildConfiguration section */',
    '''/* Begin PBXTargetDependency section */
\t\tH20000000000000000000001 /* PBXTargetDependency */ = {
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = E10000000000000000000001 /* MasterMechanic */;
\t\t\ttargetProxy = G20000000000000000000001 /* PBXContainerItemProxy */;
\t\t};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */'''
)
r(
    '/* End XCBuildConfiguration section */',
    '''\t\tF20000000000000000000006 /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.freerunner34.mastermechanic.tests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/MasterMechanic.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MasterMechanic";
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\tF20000000000000000000007 /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.freerunner34.mastermechanic.tests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/MasterMechanic.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MasterMechanic";
\t\t\t};
\t\t\tname = Release;
\t\t};
/* End XCBuildConfiguration section */'''
)
r(
    '/* End XCConfigurationList section */',
    '''\t\tF20000000000000000000003 /* Build configuration list for PBXNativeTarget "MasterMechanicTests" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (F20000000000000000000006 /* Debug */, F20000000000000000000007 /* Release */);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
/* End XCConfigurationList section */'''
)
pbx.write_text(text)

hook = ROOT / "MasterMechanic" / "ImportedCaseHook.swift"
if hook.exists():
    hook.unlink()


# 9) Preflight validator used locally and in CI.
validator = r'''#!/usr/bin/env python3
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
imported = (root / "MasterMechanic" / "ImportedBase44Cases.swift").read_text()
models = (root / "MasterMechanic" / "Models.swift").read_text()
views = (root / "MasterMechanic" / "Views.swift").read_text()
extra = (root / "MasterMechanic" / "ExtraASEQuestions.swift").read_text()
storekit_path = root / "MasterMechanic" / "MasterMechanic.storekit"

block = imported.split('private static let rawSeeds = """', 1)[1].split('"""', 1)[0]
rows = [line for line in block.splitlines() if '¦' in line]
assert len(rows) == 80, f"Expected 80 migrated ROs, found {len(rows)}"
ids = []
for number, row in enumerate(rows, 1):
    fields = row.split('¦')
    assert len(fields) == 9, f"RO row {number} has {len(fields)} fields instead of 9"
    assert fields[1] in {'E','A','T','S','M','D'}, f"RO row {number} has bad difficulty {fields[1]!r}"
    int(fields[4])
    assert fields[3].strip(), f"RO row {number} is missing vehicle"
    assert fields[5].strip(), f"RO row {number} is missing complaint"
    assert fields[7].strip(), f"RO row {number} is missing root cause"
    assert fields[8].strip(), f"RO row {number} is missing repair"
    ids.append(fields[0])
assert len(ids) == len(set(ids)), "Migrated RO IDs are not unique"

assert "example.com" not in models, "Placeholder production URL remains in Models.swift"
assert "ImportedCaseHook.swift" not in (root / "MasterMechanic.xcodeproj" / "project.pbxproj").read_text()
assert not (root / "MasterMechanic" / "ImportedCaseHook.swift").exists(), "Legacy global array operator hook still exists"
assert '$6.99 / month' not in views, "Hard-coded storefront price remains in the UI"
assert "trainingQuestions" in views, "Training view is not using the expanded question bank"

config = json.loads(storekit_path.read_text())
products = []
for group in config.get("subscriptionGroups", []):
    products.extend(group.get("subscriptions", []))
product_ids = {item.get("productID") for item in products}
assert "com.freerunner34.mastermechanic.pro.monthly" in product_ids, "Local StoreKit product ID does not match app code"

base_questions = len(re.findall(r'\n\s*q\("a[1-8]"', (root / "MasterMechanic" / "AppData.swift").read_text()))
extra_questions = len(re.findall(r'\n\s*q\("a[1-8]x[1-4]"', extra))
assert base_questions >= 8, f"Expected at least eight built-in ASE questions, found {base_questions}"
assert extra_questions == 32, f"Expected 32 extra ASE questions, found {extra_questions}"

assert (root / "PRIVACY.md").exists()
assert (root / "SUPPORT.md").exists()
assert (root / "MasterMechanicTests" / "MasterMechanicTests.swift").exists()
assert (root / "MasterMechanic.xcodeproj" / "xcshareddata" / "xcschemes" / "MasterMechanic.xcscheme").exists()

icon_contents = json.loads((root / "MasterMechanic" / "Assets.xcassets" / "AppIcon.appiconset" / "Contents.json").read_text())
has_icon_filename = any(item.get("filename") for item in icon_contents.get("images", []))

print(f"Validated {len(rows)} migrated repair orders")
print(f"Validated {base_questions + extra_questions}+ ASE-style questions")
print("Validated StoreKit product ID, production URLs, and explicit case catalog wiring")
if has_icon_filename:
    print("App icon asset is assigned")
else:
    print("WARNING: final 1024x1024 App Store icon is still not assigned")
'''
validator_path = ROOT / "scripts" / "validate_project.py"
validator_path.write_text(validator)


# 10) Update README to reflect the hardened pre-account state.
readme = ROOT / "README.md"
text = readme.read_text()
text = text.replace(
    "The repo contains a native case engine plus representative cases from the original live Base44 app across the complete difficulty ladder. It also contains an initial ASE-style bank across A1–A8. The original Base44 database currently contains substantially more generated cases/questions; those can be converted into bundled native content without changing this architecture.",
    "The native catalog includes all 80 RepairCase records migrated from the original Base44 database, plus native advanced cases across the complete difficulty ladder. Imported cases preserve each repair order's vehicle, mileage, complaint, writer notes, verified root cause, and repair while repeated Base44 case families use shared native diagnostic-test templates. The ASE-style practice bank now contains at least five questions in each A1–A8 area."
)
text = text.replace(
    "1. Add the final **1024 × 1024 App Store icon** to `Assets.xcassets/AppIcon.appiconset`.\n2. Replace the placeholder privacy URL in `AppConfig.privacyURL` with your published privacy-policy page and use the same URL in App Store Connect.\n3. Create/configure the StoreKit subscription in App Store Connect and submit it with the first app version.\n4. Set your Apple Developer Team/signing certificate in Xcode.\n5. Complete the App Privacy questionnaire so it matches the shipping binary. The current native build has no ads, tracking, Base44 SDK, analytics SDK, or app-level account.\n6. Add screenshots, description, support URL, age rating and other App Store Connect metadata.",
    "1. Add the final **1024 × 1024 App Store icon** to `Assets.xcassets/AppIcon.appiconset`.\n2. Enroll/select the Apple Developer Team and configure signing.\n3. Create/configure the StoreKit subscription in App Store Connect using `com.freerunner34.mastermechanic.pro.monthly`, then switch from local StoreKit testing to the App Store sandbox for final purchase validation.\n4. Complete the App Privacy questionnaire so it matches the shipping binary. The current native build has no ads, tracking, Base44 SDK, analytics SDK, or app-level account.\n5. Add screenshots, description, age rating and the remaining App Store Connect metadata. Public privacy and support pages are already present in this repository."
)
readme.write_text(text)

print("Pre-Apple refactor prepared successfully")
