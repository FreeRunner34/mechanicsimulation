import Foundation

struct RepairOrder: Hashable, Codable {
    let vehicle: String
    let mileage: Int
    let complaint: String
    let notes: String
}

enum Difficulty: String, CaseIterable, Identifiable, Codable {
    case entry = "Entry Level"
    case apprentice = "Apprentice"
    case technician = "Technician"
    case senior = "Senior Specialist"
    case master = "Master Technician"
    case diagnostic = "Diagnostic Specialist"

    var id: String { rawValue }
    var isPro: Bool { self != .entry && self != .apprentice }
    var shortLabel: String {
        switch self {
        case .entry: return "ENTRY"
        case .apprentice: return "APPRENTICE"
        case .technician: return "TECH"
        case .senior: return "SENIOR"
        case .master: return "MASTER"
        case .diagnostic: return "DIAGNOSTIC"
        }
    }
}

enum BayView: String, CaseIterable, Identifiable, Codable {
    case underHood = "Under Hood"
    case underCar = "Under Vehicle"
    case cockpit = "Driver Seat"
    case exterior = "Exterior"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .underHood: return "engine.combustion"
        case .underCar: return "wrench.and.screwdriver.fill"
        case .cockpit: return "steeringwheel"
        case .exterior: return "car.side.fill"
        }
    }
}

struct DiagnosticTool: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let symbol: String
    let hint: String
}

struct Inspection: Identifiable, Hashable, Codable {
    let id: String
    let view: BayView
    let label: String
    let toolID: String
    let productive: Bool
    let finding: String
}

struct DiagnosisChoice: Identifiable, Hashable, Codable {
    let id: String
    let text: String
    let correct: Bool
}

struct DiagnosticCase: Identifiable, Hashable, Codable {
    let id: String
    let difficulty: Difficulty
    let brand: String?
    let repairOrder: RepairOrder
    let tools: [DiagnosticTool]
    let inspections: [Inspection]
    let causes: [DiagnosisChoice]
    let repairs: [DiagnosisChoice]
    let explanation: String
    let rootCause: String
    let correctRepair: String
    let takeaways: [String]
}

struct ASEChoice: Identifiable, Hashable, Codable {
    let id: String
    let text: String
}

struct ASEQuestion: Identifiable, Hashable, Codable {
    let id: String
    let area: String
    let question: String
    let choices: [ASEChoice]
    let correctID: String
    let explanation: String
}

struct ToolReference: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let use: String
    let tip: String
}

enum AppConfig {
    static let proProductID = "com.freerunner34.mastermechanic.pro.monthly"
    static let privacyURL = URL(string: "https://github.com/FreeRunner34/mechanicsimulation/blob/main/PRIVACY.md")!
    static let supportURL = URL(string: "https://github.com/FreeRunner34/mechanicsimulation/blob/main/SUPPORT.md")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

// MARK: - Expanded native case catalog
//
// The original Base44 app had a large generated RO pool. The first native build
// intentionally started with one representative case per tier, which meant a
// tier with one case could only repeat that case. This catalog restores enough
// variety for continuous native play without calling Base44 at runtime.

extension AppData {
    var playableCases: [DiagnosticCase] {
        let native = cases + Self.additionalCases(using: tools)
        let existingIDs = Set(native.map(\.id))
        return native + ImportedBase44Cases.load().filter { !existingIDs.contains($0.id) }
    }

    func nextCase(difficulty: Difficulty, excluding excludedIDs: Set<String> = []) -> DiagnosticCase? {
        let pool = playableCases.filter { $0.difficulty == difficulty }
        guard !pool.isEmpty else { return nil }
        let fresh = pool.filter { !excludedIDs.contains($0.id) }
        return (fresh.isEmpty ? pool : fresh).randomElement()
    }

    private static func additionalCases(using tools: [DiagnosticTool]) -> [DiagnosticCase] {
        func tool(_ id: String) -> DiagnosticTool { tools.first { $0.id == id }! }
        func inspection(_ id: String, _ view: BayView, _ label: String, _ toolID: String, _ productive: Bool, _ finding: String) -> Inspection {
            .init(id: id, view: view, label: label, toolID: toolID, productive: productive, finding: finding)
        }
        func choice(_ id: String, _ text: String, _ correct: Bool = false) -> DiagnosisChoice {
            .init(id: id, text: text, correct: correct)
        }

        return [
            // ENTRY LEVEL
            .init(
                id: "entry-evap-canister",
                difficulty: .entry,
                brand: "Stellar Motors Corp",
                repairOrder: .init(vehicle: "2019 SMC Voyager LX", mileage: 82450, complaint: "Check-engine light is on and there is a strong raw-fuel smell near the rear of the vehicle.", notes: "Fuel cap is tight. No liquid fuel leak is visible."),
                tools: [tool("scan_tool"), tool("flashlight"), tool("smoke_machine")],
                inspections: [
                    inspection("ee1", .cockpit, "Stored DTCs", "scan_tool", true, "P0442 EVAP small-leak code is stored."),
                    inspection("ee2", .exterior, "Fuel cap seal", "flashlight", false, "Cap seal is pliable and the cap seats correctly."),
                    inspection("ee3", .underCar, "Charcoal canister smoke test", "smoke_machine", true, "Smoke escapes from a hairline crack in the canister housing."),
                    inspection("ee4", .underHood, "Purge valve", "flashlight", false, "Purge valve and visible hoses appear intact.")
                ],
                causes: [choice("c1", "Cracked charcoal canister", true), choice("c2", "Fuel pump failure"), choice("c3", "Oxygen sensor failure"), choice("c4", "Loose fuel cap")],
                repairs: [choice("r1", "Replace the cracked charcoal canister and verify EVAP integrity", true), choice("r2", "Replace the fuel pump"), choice("r3", "Replace oxygen sensors"), choice("r4", "Replace the fuel injectors")],
                explanation: "The DTC identifies the system and the smoke test physically proves the leak at the canister.",
                rootCause: "Cracked charcoal canister",
                correctRepair: "Replace the charcoal canister and verify the EVAP system seals",
                takeaways: ["EVAP codes identify a system, not automatically a component.", "Smoke testing turns an invisible vapor leak into visible evidence."]
            ),
            .init(
                id: "entry-intake-boot",
                difficulty: .entry,
                brand: "Nisshin Motors",
                repairOrder: .init(vehicle: "2018 Nisshin Kaze LX", mileage: 94500, complaint: "Vehicle is sluggish on acceleration and the Service Engine Soon lamp came on this morning.", notes: "Concern began after a long commute."),
                tools: [tool("scan_tool"), tool("flashlight"), tool("smoke_machine"), tool("pressure_gauge")],
                inspections: [
                    inspection("ei1", .cockpit, "Fuel-trim DTCs", "scan_tool", true, "P0171 System Too Lean Bank 1 is stored."),
                    inspection("ei2", .underHood, "Air-intake boot", "flashlight", true, "A crack is visible in the accordion section after the airflow sensor."),
                    inspection("ei3", .underHood, "Intake smoke test", "smoke_machine", true, "Smoke pours from the crack in the intake boot."),
                    inspection("ei4", .underHood, "Fuel pressure", "pressure_gauge", false, "Fuel pressure is within specification.")
                ],
                causes: [choice("c1", "Cracked intake boot allowing unmetered air", true), choice("c2", "Weak fuel pump"), choice("c3", "Failed catalytic converter"), choice("c4", "Transmission failure")],
                repairs: [choice("r1", "Replace the damaged intake boot and clear/adapt fuel trims", true), choice("r2", "Replace fuel pump"), choice("r3", "Replace MAF without testing"), choice("r4", "Replace catalytic converter")],
                explanation: "The lean code plus a confirmed post-MAF air leak proves unmetered air is creating the drivability concern.",
                rootCause: "Cracked air-intake boot",
                correctRepair: "Replace the damaged intake boot and verify fuel trims",
                takeaways: ["A lean code can be too much air, not just too little fuel.", "Always inspect rubber intake plumbing before condemning sensors."]
            ),
            .init(
                id: "entry-ev-12v",
                difficulty: .entry,
                brand: "Aeon Mobility",
                repairOrder: .init(vehicle: "2021 Aeon Flux EV", mileage: 42150, complaint: "Vehicle will not enter Ready mode; dash flickers and several system warnings appear.", notes: "It worked yesterday and has been sitting overnight."),
                tools: [tool("scan_tool"), tool("multimeter"), tool("flashlight")],
                inspections: [
                    inspection("ev1", .cockpit, "Module scan", "scan_tool", true, "Multiple low-voltage and communication codes are stored across unrelated modules."),
                    inspection("ev2", .underHood, "12-volt battery", "multimeter", true, "Battery measures 9.2 V at rest and collapses further when the start button is pressed."),
                    inspection("ev3", .underHood, "Battery terminals", "flashlight", false, "Connections are clean and tight."),
                    inspection("ev4", .underCar, "High-voltage battery case", "flashlight", false, "HV battery enclosure is undamaged and dry.")
                ],
                causes: [choice("c1", "Failed 12-volt auxiliary battery", true), choice("c2", "Failed HV battery pack"), choice("c3", "Inverter failure"), choice("c4", "Start-button failure")],
                repairs: [choice("r1", "Replace/test the 12-volt auxiliary battery and clear low-voltage codes", true), choice("r2", "Replace HV battery"), choice("r3", "Replace inverter"), choice("r4", "Replace start button")],
                explanation: "EV control modules still depend on the 12-volt system to wake up and close the high-voltage contactors.",
                rootCause: "Failed 12-volt auxiliary battery",
                correctRepair: "Replace the failed 12-volt battery and verify system initialization",
                takeaways: ["An EV can have a charged traction battery and still be disabled by its 12-volt battery.", "Low voltage often creates many misleading communication codes."]
            ),
            .init(
                id: "entry-range-sensor-wiring",
                difficulty: .entry,
                brand: "Nisshin Motors",
                repairOrder: .init(vehicle: "2018 Nisshin Kaze", mileage: 94200, complaint: "Vehicle jerks from a stop and sometimes the gear indicator does not match the shifter position.", notes: "Service Engine Soon lamp came on yesterday."),
                tools: [tool("scan_tool"), tool("flashlight"), tool("multimeter"), tool("test_drive")],
                inspections: [
                    inspection("er1", .cockpit, "Transmission codes", "scan_tool", true, "P0705 Transmission Range Sensor Circuit Malfunction is stored."),
                    inspection("er2", .underHood, "Range-sensor harness", "flashlight", true, "Harness insulation is heat-damaged where it contacts a shield."),
                    inspection("er3", .underHood, "Range sensor", "multimeter", false, "Sensor resistance changes correctly through PRNDL when tested directly."),
                    inspection("er4", .exterior, "Road validation", "test_drive", true, "Moving the damaged harness causes the gear display to flicker and the vehicle to enter fail-safe mode.")
                ],
                causes: [choice("c1", "Damaged transmission range-sensor wiring", true), choice("c2", "Failed CVT belt"), choice("c3", "Fuel injector failure"), choice("c4", "Torque converter failure")],
                repairs: [choice("r1", "Repair and reroute the damaged harness, then verify range data", true), choice("r2", "Replace CVT"), choice("r3", "Replace range sensor despite passing test"), choice("r4", "Flush transmission")],
                explanation: "The sensor itself passes, while harness movement reproduces the fault. That isolates the circuit rather than the transmission internals.",
                rootCause: "Heat-damaged transmission range-sensor harness",
                correctRepair: "Repair/reroute the damaged wiring and validate PRNDL data",
                takeaways: ["A sensor DTC does not automatically mean the sensor failed.", "Reproduce intermittent electrical faults while monitoring the circuit."]
            ),
            .init(
                id: "entry-bayern-thermostat",
                difficulty: .entry,
                brand: "Bayern Werke",
                repairOrder: .init(vehicle: "2018 Bayern Werke 330i", mileage: 82450, complaint: "Cooling fan runs at full speed and an engine-temperature warning appears shortly after startup.", notes: "Coolant level appears normal."),
                tools: [tool("scan_tool"), tool("multimeter"), tool("pressure_gauge"), tool("flashlight")],
                inspections: [
                    inspection("et1", .cockpit, "Cooling-system DTC", "scan_tool", true, "P0597 thermostat-heater circuit open is stored."),
                    inspection("et2", .underHood, "Thermostat circuit", "multimeter", true, "Power is present, but the thermostat heater measures open circuit."),
                    inspection("et3", .underHood, "Cooling-system pressure", "pressure_gauge", false, "System holds pressure and no external leak is found."),
                    inspection("et4", .underHood, "Coolant level", "flashlight", false, "Coolant is at the correct level.")
                ],
                causes: [choice("c1", "Failed electronic thermostat", true), choice("c2", "Blown head gasket"), choice("c3", "Low coolant"), choice("c4", "Radiator restriction")],
                repairs: [choice("r1", "Replace the electronic thermostat assembly and bleed cooling system", true), choice("r2", "Replace cooling fan"), choice("r3", "Replace radiator"), choice("r4", "Replace engine")],
                explanation: "The PCM sees an open heater circuit and power is present at the component, proving the thermostat assembly has failed electrically.",
                rootCause: "Open electronic thermostat heater",
                correctRepair: "Replace thermostat assembly and bleed/verify cooling operation",
                takeaways: ["Fail-safe fan operation can be a response to a control fault, not proof the fan is bad.", "Verify power and component resistance before replacing parts."]
            ),

            // APPRENTICE
            .init(
                id: "apprentice-hybrid-fan",
                difficulty: .apprentice,
                brand: "Aeon Mobility",
                repairOrder: .init(vehicle: "2019 Aeon Zenith Hybrid", mileage: 82450, complaint: "System Fault warning appears and a very loud cooling fan runs after longer drives.", notes: "Owner transports pets frequently."),
                tools: [tool("scan_tool"), tool("flashlight"), tool("multimeter")],
                inspections: [
                    inspection("ah1", .cockpit, "Hybrid DTCs", "scan_tool", true, "Battery cooling fan performance and circuit codes are stored."),
                    inspection("ah2", .underHood, "Battery cooling intake", "flashlight", true, "Cooling intake is packed with pet hair and dust."),
                    inspection("ah3", .underHood, "Cooling fan current path", "multimeter", true, "Supply voltage is correct, but fan motor resistance/current behavior is abnormal."),
                    inspection("ah4", .underCar, "Battery case", "flashlight", false, "HV battery enclosure shows no impact or moisture damage.")
                ],
                causes: [choice("c1", "Failed battery cooling fan from restricted intake", true), choice("c2", "HV battery pack failure"), choice("c3", "DC-DC converter failure"), choice("c4", "Engine radiator fan")],
                repairs: [choice("r1", "Clear the duct and replace the damaged battery cooling fan", true), choice("r2", "Replace HV battery"), choice("r3", "Replace inverter"), choice("r4", "Replace engine radiator")],
                explanation: "The physical restriction overloaded the fan, and electrical testing confirms the motor has been damaged.",
                rootCause: "Restricted HV-battery cooling duct and failed fan motor",
                correctRepair: "Clean the duct and replace the damaged cooling fan",
                takeaways: ["Inspect airflow paths before condemning expensive hybrid components.", "A root cause can include both the failed part and what caused it to fail."]
            ),
            .init(
                id: "apprentice-purge-stall",
                difficulty: .apprentice,
                brand: "Stellar Motors Corp",
                repairOrder: .init(vehicle: "2020 SMC Titan V8", mileage: 73110, complaint: "After filling the tank, the engine is hard to restart and sometimes stalls at the first stoplight.", notes: "Concern is strongest immediately after refueling."),
                tools: [tool("scan_tool"), tool("smoke_machine"), tool("multimeter"), tool("test_drive")],
                inspections: [
                    inspection("ap1", .cockpit, "EVAP data", "scan_tool", true, "P0496 EVAP flow during non-purge is current; fuel trims go strongly negative after restart."),
                    inspection("ap2", .underHood, "Purge valve sealing", "smoke_machine", true, "Smoke passes through the purge valve while it is commanded closed."),
                    inspection("ap3", .underHood, "Purge solenoid electrical test", "multimeter", false, "Coil resistance and command voltage are within specification."),
                    inspection("ap4", .exterior, "Post-refuel road test", "test_drive", true, "Rough running occurs immediately after refuel and clears as excess vapor is consumed.")
                ],
                causes: [choice("c1", "Purge valve mechanically stuck open", true), choice("c2", "Fuel pump weak"), choice("c3", "Throttle body failure"), choice("c4", "Crank sensor")],
                repairs: [choice("r1", "Replace the purge valve and verify commanded sealing", true), choice("r2", "Replace fuel pump"), choice("r3", "Clean injectors"), choice("r4", "Replace throttle body")],
                explanation: "The valve has proper electrical control but physically leaks when commanded closed, allowing excess tank vapor into the engine after refueling.",
                rootCause: "EVAP purge valve stuck mechanically open",
                correctRepair: "Replace purge valve and verify no flow when commanded closed",
                takeaways: ["Separate electrical control from mechanical sealing.", "Symptom timing after refueling is a major diagnostic clue."]
            ),
            .init(
                id: "apprentice-wheel-speed",
                difficulty: .apprentice,
                brand: "Bayern Werke",
                repairOrder: .init(vehicle: "2020 Bayern Werke R3 Touring", mileage: 66940, complaint: "ABS activates just before the vehicle stops on dry pavement, but no warning lamp stays on.", notes: "Right-front wheel bearing was recently replaced."),
                tools: [tool("scan_tool"), tool("flashlight"), tool("multimeter"), tool("test_drive")],
                inspections: [
                    inspection("aw1", .cockpit, "Wheel-speed graph", "scan_tool", true, "Right-front speed drops to zero intermittently at 4–5 mph while the other wheels still report speed."),
                    inspection("aw2", .underCar, "Right-front encoder", "flashlight", true, "Metallic debris is stuck to the magnetic encoder surface."),
                    inspection("aw3", .underCar, "Wheel-speed circuit", "multimeter", false, "Sensor power, ground and wiring pass static checks."),
                    inspection("aw4", .exterior, "Low-speed validation", "test_drive", true, "After cleaning the encoder area, all four wheel speeds track evenly and false ABS activation stops.")
                ],
                causes: [choice("c1", "Contaminated right-front magnetic encoder signal", true), choice("c2", "ABS hydraulic unit failure"), choice("c3", "Brake booster failure"), choice("c4", "Rear wheel-speed sensor")],
                repairs: [choice("r1", "Correct encoder contamination/damage and verify live wheel speeds", true), choice("r2", "Replace ABS module"), choice("r3", "Replace master cylinder"), choice("r4", "Flush brake fluid")],
                explanation: "One wheel-speed input drops out at walking speed and cleaning the encoder restores the signal, proving the false ABS event source.",
                rootCause: "Right-front magnetic wheel-speed encoder contamination",
                correctRepair: "Correct the encoder/sensor interface and validate wheel-speed data",
                takeaways: ["Graph related sensors together so one outlier is obvious.", "Recent repairs near the concern deserve inspection."]
            ),

            // TECHNICIAN
            .init(
                id: "technician-lifter",
                difficulty: .technician,
                brand: "Stellar Motors Corp",
                repairOrder: .init(vehicle: "2018 SMC Sentinel V8", mileage: 92450, complaint: "Warm engine develops a rhythmic passenger-side tick, check-engine light and slight power loss.", notes: "Noise is difficult to reproduce cold."),
                tools: [tool("scan_tool"), tool("stethoscope"), tool("pressure_gauge"), tool("flashlight"), tool("test_drive")],
                inspections: [
                    inspection("tl1", .cockpit, "Misfire data", "scan_tool", true, "P0304 is stored and cylinder 4 misfire counts rise after warm-up."),
                    inspection("tl2", .underHood, "Valve-cover noise", "stethoscope", true, "Rhythmic metallic tap is localized over the cylinder 4 intake-lifter area."),
                    inspection("tl3", .underHood, "Cylinder 4 compression", "pressure_gauge", true, "Cylinder 4 is lower than companion cylinders, consistent with reduced valve lift."),
                    inspection("tl4", .underHood, "Spark plug", "flashlight", false, "Spark plug coloration and gap are normal."),
                    inspection("tl5", .exterior, "Warm road test", "test_drive", true, "Misfire increases at mid-range RPM after oil reaches operating temperature.")
                ],
                causes: [choice("c1", "Collapsed hydraulic lifter on cylinder 4", true), choice("c2", "Fuel injector restriction"), choice("c3", "EVAP leak"), choice("c4", "Crankshaft bearing")],
                repairs: [choice("r1", "Replace failed lifter and inspect associated cam lobe", true), choice("r2", "Replace injectors"), choice("r3", "Replace ignition coil"), choice("r4", "Replace complete engine without inspection")],
                explanation: "The misfire, localized mechanical tick and reduced compression all point to a valve-lift problem rather than an ignition or fuel fault.",
                rootCause: "Collapsed hydraulic valve lifter",
                correctRepair: "Replace the failed lifter and inspect the camshaft lobe",
                takeaways: ["Use sound location together with scan data.", "A cylinder misfire can be mechanical even when ignition parts look fine."]
            ),
            .init(
                id: "technician-hpfp",
                difficulty: .technician,
                brand: "Bayern Werke",
                repairOrder: .init(vehicle: "2018 Bayern Werke X5-Sport", mileage: 68420, complaint: "Power drops sharply during highway passing and the engine lamp appears only under heavy throttle.", notes: "Idle quality is normal."),
                tools: [tool("scan_tool"), tool("pressure_gauge"), tool("smoke_machine"), tool("test_drive")],
                inspections: [
                    inspection("th1", .cockpit, "Freeze-frame data", "scan_tool", true, "P0087 Fuel Rail/System Pressure Too Low sets during high-load demand."),
                    inspection("th2", .underHood, "Fuel pressure under load", "pressure_gauge", true, "Pressure is acceptable at idle but falls far below commanded pressure as load increases."),
                    inspection("th3", .underHood, "Intake leak test", "smoke_machine", false, "Induction system holds smoke pressure with no leaks."),
                    inspection("th4", .exterior, "Loaded road test", "test_drive", true, "Power loss occurs exactly as actual rail pressure separates from commanded pressure.")
                ],
                causes: [choice("c1", "High-pressure fuel pump cannot meet demand", true), choice("c2", "Boost leak"), choice("c3", "Transmission slip"), choice("c4", "Coolant sensor")],
                repairs: [choice("r1", "Replace the failed high-pressure pump and verify commanded/actual pressure", true), choice("r2", "Replace turbocharger"), choice("r3", "Replace transmission"), choice("r4", "Replace MAF")],
                explanation: "The pressure failure happens under the exact load condition that creates the symptom, while the intake system is sealed.",
                rootCause: "High-pressure fuel pump volume failure",
                correctRepair: "Replace the high-pressure fuel pump and verify rail pressure under load",
                takeaways: ["Test fuel pressure under the condition where the complaint occurs.", "Commanded versus actual data is more useful than a static idle reading."]
            ),
            .init(
                id: "technician-tcc-shudder",
                difficulty: .technician,
                brand: "Kestrel Automotive",
                repairOrder: .init(vehicle: "2019 Kestrel Atlas AWD", mileage: 88750, complaint: "Light-throttle cruising at 45–55 mph produces a vibration like driving over rumble strips.", notes: "No vibration during hard acceleration."),
                tools: [tool("scan_tool"), tool("test_drive"), tool("flashlight")],
                inspections: [
                    inspection("tt1", .cockpit, "Torque-converter slip data", "scan_tool", true, "Vibration occurs while TCC is commanded applied and slip oscillates 80–220 rpm."),
                    inspection("tt2", .exterior, "TCC road test", "test_drive", true, "Light brake-pedal input releases TCC and the vibration immediately disappears."),
                    inspection("tt3", .underCar, "Driveshaft and mounts", "flashlight", false, "Driveshaft joints and mounts show no abnormal play or damage."),
                    inspection("tt4", .cockpit, "Engine misfire counters", "scan_tool", false, "No cylinder misfire counts increase during the vibration.")
                ],
                causes: [choice("c1", "Torque-converter clutch shudder", true), choice("c2", "Engine misfire"), choice("c3", "Wheel imbalance"), choice("c4", "Rear differential failure")],
                repairs: [choice("r1", "Perform the specified TCC fluid/service procedure and repair converter if shudder remains", true), choice("r2", "Replace ignition coils"), choice("r3", "Balance tires only"), choice("r4", "Replace differential")],
                explanation: "The vibration is tied directly to TCC application and disappears the instant the clutch is commanded off.",
                rootCause: "Torque-converter clutch shudder",
                correctRepair: "Perform the correct transmission/TCC service path and replace converter if required",
                takeaways: ["Use control commands to make a symptom appear and disappear.", "A vibration can originate from drivetrain control rather than tires or engine misfire."]
            ),

            // SENIOR SPECIALIST
            .init(
                id: "senior-parasitic-draw",
                difficulty: .senior,
                brand: "Bayern Werke",
                repairOrder: .init(vehicle: "2021 Bayern Werke X5", mileage: 51200, complaint: "Battery is dead every two or three mornings even though the battery and alternator were recently replaced.", notes: "No warning lamps while driving."),
                tools: [tool("multimeter"), tool("scan_tool"), tool("flashlight")],
                inspections: [
                    inspection("sp1", .underHood, "Key-off current after sleep", "multimeter", true, "Current remains at 620 mA more than 30 minutes after shutdown."),
                    inspection("sp2", .cockpit, "Module sleep status", "scan_tool", true, "Infotainment gateway repeatedly wakes on the body network."),
                    inspection("sp3", .underCar, "Alternator diode leakage", "multimeter", false, "Alternator backfeed is within normal limits."),
                    inspection("sp4", .cockpit, "Center-console USB hub", "flashlight", true, "Liquid residue and corrosion are visible inside the USB hub connector."),
                    inspection("sp5", .cockpit, "Draw with USB hub disconnected", "multimeter", true, "Key-off draw falls to 28 mA and the network remains asleep.")
                ],
                causes: [choice("c1", "Corroded USB hub keeping the infotainment network awake", true), choice("c2", "Bad new battery"), choice("c3", "Alternator diode leak"), choice("c4", "Starter short")],
                repairs: [choice("r1", "Replace/repair the corroded hub and verify sleep current", true), choice("r2", "Replace battery again"), choice("r3", "Replace alternator"), choice("r4", "Replace starter")],
                explanation: "The draw persists after normal sleep time, scan data identifies the waking network, and disconnecting the corroded hub proves the source.",
                rootCause: "Corroded infotainment USB hub preventing network sleep",
                correctRepair: "Replace/repair the USB hub and confirm normal sleep current",
                takeaways: ["Parasitic-draw diagnosis requires waiting for module sleep.", "Use fuse/component isolation only after proving the draw is abnormal."]
            ),
            .init(
                id: "senior-crank-sensor-harness",
                difficulty: .senior,
                brand: "Nisshin Motors",
                repairOrder: .init(vehicle: "2020 Nisshin Sentier", mileage: 76300, complaint: "Engine shuts off over rough railroad crossings and usually restarts immediately.", notes: "No symptom on smooth roads."),
                tools: [tool("scan_tool"), tool("multimeter"), tool("flashlight"), tool("test_drive")],
                inspections: [
                    inspection("sc1", .cockpit, "Event data", "scan_tool", true, "RPM signal drops instantly to zero during the stall while cam position remains plausible."),
                    inspection("sc2", .underHood, "Crank-sensor harness", "flashlight", true, "Harness is stretched tightly across a bracket near the lower engine mount."),
                    inspection("sc3", .underHood, "Crank signal static", "multimeter", false, "Circuit reads normally while the vehicle is stationary."),
                    inspection("sc4", .underHood, "Harness wiggle signal", "multimeter", true, "Flexing the harness opens the signal circuit momentarily."),
                    inspection("sc5", .exterior, "Rough-road validation", "test_drive", true, "After harness repair/reroute, the original railroad crossing no longer causes a stall.")
                ],
                causes: [choice("c1", "Intermittent open in crank-sensor harness", true), choice("c2", "Failed fuel pump"), choice("c3", "PCM software"), choice("c4", "Camshaft sensor")],
                repairs: [choice("r1", "Repair/reroute the damaged crank-sensor circuit and stress-test it", true), choice("r2", "Replace PCM"), choice("r3", "Replace fuel pump"), choice("r4", "Replace both cam sensors")],
                explanation: "Only crank RPM disappears during the event, and harness stress reproduces the open circuit even though static testing passes.",
                rootCause: "Intermittent crankshaft-position sensor harness open",
                correctRepair: "Repair and reroute the damaged crank-sensor wiring",
                takeaways: ["Intermittent faults often pass stationary resistance tests.", "Capture what data disappears at the exact moment of failure."]
            ),
            .init(
                id: "senior-fuel-pump-control",
                difficulty: .senior,
                brand: "Kestrel Automotive",
                repairOrder: .init(vehicle: "2021 Kestrel Vector Turbo", mileage: 59200, complaint: "Long crank occurs only after a hot soak; cold starts are always normal.", notes: "No current DTCs."),
                tools: [tool("scan_tool"), tool("pressure_gauge"), tool("multimeter"), tool("test_drive")],
                inspections: [
                    inspection("sf1", .underHood, "Hot-soak fuel pressure", "pressure_gauge", true, "Rail pressure bleeds to nearly zero within minutes of shutdown when hot."),
                    inspection("sf2", .cockpit, "Pump command during hot restart", "scan_tool", true, "PCM commands normal pump duty during the extended crank."),
                    inspection("sf3", .underCar, "Pump supply voltage", "multimeter", true, "Voltage at the pump drops several volts only when the fuel-pump control module is heat soaked."),
                    inspection("sf4", .exterior, "Cold-start comparison", "test_drive", false, "Cold restart is immediate and pressure builds normally."),
                    inspection("sf5", .underCar, "Control module connector", "flashlight", true, "Connector terminals show heat discoloration and loss of pin tension.")
                ],
                causes: [choice("c1", "Heat-sensitive resistance at fuel-pump control module connector", true), choice("c2", "Leaking injector"), choice("c3", "Starter failure"), choice("c4", "Crank sensor")],
                repairs: [choice("r1", "Repair the overheated connector/control circuit and verify hot restart pressure", true), choice("r2", "Replace all injectors"), choice("r3", "Replace starter"), choice("r4", "Replace crank sensor")],
                explanation: "The PCM is commanding the pump, but supply voltage collapses at a heat-damaged connector only after hot soak.",
                rootCause: "Heat-damaged fuel-pump control module connector",
                correctRepair: "Repair the connector/control circuit and verify hot-soak operation",
                takeaways: ["Temperature can be the trigger for electrical resistance.", "Compare command with what the component actually receives."]
            ),

            // MASTER TECHNICIAN
            .init(
                id: "master-false-trans-slip",
                difficulty: .master,
                brand: "Stellar Motors Corp",
                repairOrder: .init(vehicle: "2020 SMC Vanguard 3.6", mileage: 104200, complaint: "Feels like the transmission slips during long uphill pulls, but there are no transmission codes.", notes: "Transmission was serviced elsewhere with no improvement."),
                tools: [tool("scan_tool"), tool("pressure_gauge"), tool("test_drive"), tool("smoke_machine")],
                inspections: [
                    inspection("mf1", .cockpit, "Transmission ratio data", "scan_tool", true, "Commanded and actual gear/ratio remain matched while engine torque output falls."),
                    inspection("mf2", .cockpit, "Fuel trims and lambda", "scan_tool", true, "Fuel trims climb positive under sustained load and commanded enrichment cannot be maintained."),
                    inspection("mf3", .underHood, "Fuel pressure under sustained load", "pressure_gauge", true, "Pressure slowly decays after 20–30 seconds of high demand."),
                    inspection("mf4", .underHood, "Induction smoke test", "smoke_machine", false, "No intake or boost leaks are found."),
                    inspection("mf5", .exterior, "Hill-climb data log", "test_drive", true, "The perceived 'slip' begins exactly when fuel pressure decays, while transmission ratio remains stable.")
                ],
                causes: [choice("c1", "Restricted fuel-pump pickup causing sustained-load starvation", true), choice("c2", "Transmission clutch failure"), choice("c3", "Boost leak"), choice("c4", "Wheel-speed sensor")],
                repairs: [choice("r1", "Service/replace the restricted pump module and verify sustained fuel delivery", true), choice("r2", "Rebuild transmission"), choice("r3", "Replace turbo"), choice("r4", "Replace TCM")],
                explanation: "The transmission data never slips. Engine torque falls because fuel supply cannot sustain long-duration demand, creating a sensation that mimics transmission slip.",
                rootCause: "Fuel-pump pickup restriction under sustained load",
                correctRepair: "Repair the fuel-pump module/pickup restriction and validate on a sustained-load road test",
                takeaways: ["Customer-described 'slip' is a symptom, not a diagnosis.", "Long-duration load can expose volume problems that short tests miss."]
            ),
            .init(
                id: "master-brake-drag",
                difficulty: .master,
                brand: "Bayern Werke",
                repairOrder: .init(vehicle: "2019 Bayern Werke X4", mileage: 79800, complaint: "Vehicle becomes sluggish after 30 minutes of driving and fuel economy has dropped. No warning lamps.", notes: "Concern disappears after the vehicle cools for an hour."),
                tools: [tool("scan_tool"), tool("test_drive"), tool("flashlight"), tool("pressure_gauge")],
                inspections: [
                    inspection("mb1", .cockpit, "Powertrain data", "scan_tool", false, "Engine load, trims and transmission ratios remain normal during the drag sensation."),
                    inspection("mb2", .exterior, "Extended road test", "test_drive", true, "Vehicle coasts normally cold but loses coast-down distance as the concern develops."),
                    inspection("mb3", .underCar, "Wheel temperature/inspection", "flashlight", true, "Right-front brake area is dramatically hotter than the other corners and the wheel is difficult to rotate."),
                    inspection("mb4", .underCar, "Hydraulic release check", "pressure_gauge", true, "Opening the right-front bleeder immediately frees the wheel, proving trapped hydraulic pressure rather than a seized bearing.")
                ],
                causes: [choice("c1", "Right-front brake hose internally restricting return flow", true), choice("c2", "Transmission overheating"), choice("c3", "Wheel bearing seizure"), choice("c4", "Fuel trim fault")],
                repairs: [choice("r1", "Replace the restricted brake hose, inspect pads/rotor and flush/verify release", true), choice("r2", "Replace transmission"), choice("r3", "Replace wheel bearing only"), choice("r4", "Replace fuel pump")],
                explanation: "The brake applies normally but cannot release as heat builds. Cracking the bleeder releases the trapped pressure, separating a hydraulic restriction from a mechanical caliper/bearing problem.",
                rootCause: "Internally restricted right-front brake flex hose",
                correctRepair: "Replace the restricted hose and service any heat-damaged brake components",
                takeaways: ["A hot wheel does not automatically mean the caliper itself is seized.", "Use a pressure-release test to separate hydraulic from mechanical drag."]
            ),
            .init(
                id: "master-secondary-air",
                difficulty: .master,
                brand: "Kestrel Automotive",
                repairOrder: .init(vehicle: "2020 Kestrel Talon Turbo", mileage: 68300, complaint: "Cold-start check-engine lamp returns every few weeks, but the vehicle drives perfectly after warming up.", notes: "Secondary-air pump has already been replaced elsewhere."),
                tools: [tool("scan_tool"), tool("multimeter"), tool("flashlight"), tool("test_drive")],
                inspections: [
                    inspection("ma1", .cockpit, "Cold-start secondary-air data", "scan_tool", true, "PCM commands the air pump on, but front oxygen sensor response shows little added oxygen on Bank 1."),
                    inspection("ma2", .underHood, "Air-pump power/current", "multimeter", false, "Pump receives correct power and current draw is normal."),
                    inspection("ma3", .underHood, "Bank 1 air passage", "flashlight", true, "Heavy carbon is visible in the Bank 1 secondary-air feed passage."),
                    inspection("ma4", .exterior, "Warm road test", "test_drive", false, "Vehicle performs normally once secondary-air monitoring ends.")
                ],
                causes: [choice("c1", "Carbon-blocked Bank 1 secondary-air passage", true), choice("c2", "Failed replacement air pump"), choice("c3", "Transmission fault"), choice("c4", "Fuel pump")],
                repairs: [choice("r1", "Clean/repair the blocked secondary-air passage and verify cold-start monitor", true), choice("r2", "Replace air pump again"), choice("r3", "Replace oxygen sensors without testing"), choice("r4", "Replace catalytic converter")],
                explanation: "The pump is commanded and electrically healthy, but oxygen response is missing only on one bank and a physical passage restriction is present.",
                rootCause: "Carbon-blocked Bank 1 secondary-air injection passage",
                correctRepair: "Restore airflow through the blocked passage and verify the cold-start monitor",
                takeaways: ["A replaced component can be innocent when the system around it is restricted.", "Compare bank-to-bank sensor response during the exact monitor window."]
            ),

            // DIAGNOSTIC SPECIALIST
            .init(
                id: "diagnostic-shared-ground",
                difficulty: .diagnostic,
                brand: "Stellar Motors Corp",
                repairOrder: .init(vehicle: "2022 SMC Meridian", mileage: 48200, complaint: "Randomly loses throttle response, ABS warning appears and the transmission shifts harshly for a few seconds.", notes: "Several modules set unrelated voltage codes at the same timestamp."),
                tools: [tool("scan_tool"), tool("multimeter"), tool("flashlight"), tool("test_drive")],
                inspections: [
                    inspection("dg1", .cockpit, "Network code timestamp", "scan_tool", true, "Throttle, ABS and TCM all log low-reference/low-voltage events within the same second."),
                    inspection("dg2", .underHood, "Shared module ground static", "multimeter", false, "Ground resistance looks normal with the vehicle stationary."),
                    inspection("dg3", .underHood, "Ground splice inspection", "flashlight", true, "A common ground splice under the battery tray shows green corrosion hidden beneath tape."),
                    inspection("dg4", .underHood, "Loaded voltage drop at splice", "multimeter", true, "Ground drop spikes above 2 V when several modules are active simultaneously."),
                    inspection("dg5", .exterior, "Loaded road validation", "test_drive", true, "After repairing the splice, throttle/ABS/shift events no longer occur during the same route.")
                ],
                causes: [choice("c1", "High resistance in a shared module ground splice", true), choice("c2", "Three simultaneous module failures"), choice("c3", "CAN terminating resistor"), choice("c4", "Weak alternator")],
                repairs: [choice("r1", "Repair the corroded shared ground splice and validate voltage drop under load", true), choice("r2", "Replace throttle body, ABS module and TCM"), choice("r3", "Add a CAN terminator"), choice("r4", "Replace alternator")],
                explanation: "Multiple unrelated modules fail together because they share a ground. Static resistance hides the problem; loaded voltage-drop testing exposes it.",
                rootCause: "Corroded high-resistance shared module ground splice",
                correctRepair: "Repair the shared ground splice and verify loaded voltage drop",
                takeaways: ["Common power and ground paths explain simultaneous unrelated faults.", "Voltage-drop testing under load beats static resistance on high-current/shared circuits."]
            ),
            .init(
                id: "diagnostic-can-termination-intermit",
                difficulty: .diagnostic,
                brand: "Bayern Werke",
                repairOrder: .init(vehicle: "2021 Bayern Werke R5", mileage: 55700, complaint: "Entire instrument cluster occasionally resets when the passenger seat is moved fully rearward.", notes: "Vehicle otherwise drives normally."),
                tools: [tool("scan_tool"), tool("multimeter"), tool("flashlight")],
                inspections: [
                    inspection("dc1", .cockpit, "Network scan", "scan_tool", true, "Many modules record brief bus-off/lost-communication faults at the same timestamp."),
                    inspection("dc2", .cockpit, "CAN resistance seat forward", "multimeter", false, "Network measures the expected ~60 ohms with the seat in its normal position."),
                    inspection("dc3", .cockpit, "Under-seat harness", "flashlight", true, "Seat frame pinches a body-network branch when moved fully rearward."),
                    inspection("dc4", .cockpit, "CAN resistance while moving seat", "multimeter", true, "Resistance abruptly changes and the bus collapses as the harness is pinched."),
                    inspection("dc5", .cockpit, "Harness isolated", "scan_tool", true, "With the branch repaired and routed correctly, moving the seat no longer creates communication dropouts.")
                ],
                causes: [choice("c1", "Seat-frame pinch intermittently shorting the CAN branch", true), choice("c2", "Failed instrument cluster"), choice("c3", "Battery internal fault"), choice("c4", "Gateway software")],
                repairs: [choice("r1", "Repair/reroute the pinched CAN branch and validate full seat travel", true), choice("r2", "Replace cluster"), choice("r3", "Replace battery"), choice("r4", "Replace gateway module")],
                explanation: "The network is perfectly normal until a mechanical movement pinches the branch. Dynamic resistance monitoring reproduces the bus collapse.",
                rootCause: "Intermittently pinched CAN wiring under passenger seat",
                correctRepair: "Repair and reroute the CAN branch, then verify network integrity through full seat travel",
                takeaways: ["Physical movement can be the trigger for a digital network fault.", "A correct 60-ohm static reading does not clear an intermittent CAN problem."]
            ),
            .init(
                id: "diagnostic-reference-sensor-short",
                difficulty: .diagnostic,
                brand: "Kestrel Automotive",
                repairOrder: .init(vehicle: "2022 Kestrel Atlas 2.0T", mileage: 41800, complaint: "Engine intermittently stalls when turning left hard, then restarts with multiple sensor codes.", notes: "Codes involve pressure and position sensors on different systems."),
                tools: [tool("scan_tool"), tool("multimeter"), tool("flashlight"), tool("test_drive")],
                inspections: [
                    inspection("dr1", .cockpit, "DTC grouping", "scan_tool", true, "Several unrelated sensors report circuit-low faults and all share Reference 2 from the PCM."),
                    inspection("dr2", .underHood, "Reference 2 stationary", "multimeter", false, "Reference measures 5.01 V while parked."),
                    inspection("dr3", .underHood, "A/C pressure sensor branch", "flashlight", true, "Harness has a rub-through point where engine movement pulls it against a bracket."),
                    inspection("dr4", .underHood, "Reference during engine roll", "multimeter", true, "Loading the drivetrain to the left collapses Reference 2 below 1 V."),
                    inspection("dr5", .exterior, "Left-turn validation", "test_drive", true, "After harness repair, repeated hard-left maneuvers no longer cause a stall or sensor-code cluster.")
                ],
                causes: [choice("c1", "A/C pressure-sensor branch intermittently shorts shared 5-V Reference 2", true), choice("c2", "PCM internal regulator failure"), choice("c3", "Multiple failed sensors"), choice("c4", "Fuel pump")],
                repairs: [choice("r1", "Repair/reroute the chafed reference branch and dynamically stress-test it", true), choice("r2", "Replace PCM"), choice("r3", "Replace all sensors with circuit-low codes"), choice("r4", "Replace fuel pump")],
                explanation: "The common denominator is the shared reference. Engine movement during left turns lets one chafed sensor branch drag down every sensor on that reference.",
                rootCause: "Chafed A/C pressure-sensor branch shorting shared 5-V reference",
                correctRepair: "Repair/reroute the chafed reference circuit and validate under drivetrain movement",
                takeaways: ["Group DTCs by shared circuit rather than by component name.", "Reproduce the mechanical condition that moves the harness."]
            )
        ]
    }
}
