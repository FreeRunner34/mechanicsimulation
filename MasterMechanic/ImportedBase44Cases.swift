import Foundation

/// Offline copy of the RepairCase records migrated from the original Base44 app.
/// The RO/customer-facing data and verified root-cause/repair are preserved here,
/// while repeated case families share native diagnostic test templates.
enum ImportedBase44Cases {
    private struct Seed {
        let id: String
        let difficulty: Difficulty
        let brand: String?
        let vehicle: String
        let mileage: Int
        let complaint: String
        let notes: String
        let rootCause: String
        let repair: String
    }

    private enum Family {
        case ignition, evap, intake, battery, transmission, cooling, fuel, valvetrain, hybridCooling
    }

    static func load() -> [DiagnosticCase] {
        seeds.map(makeCase)
    }

    static var importedCount: Int { seeds.count }

    private static var seeds: [Seed] {
        rawSeeds
            .split(whereSeparator: \.isNewline)
            .compactMap(parseSeed)
    }

    private static func parseSeed(_ line: Substring) -> Seed? {
        let p = line.split(separator: "¦", omittingEmptySubsequences: false).map(String.init)
        guard p.count == 9, let mileage = Int(p[4]), let difficulty = difficulty(from: p[1]) else { return nil }
        return Seed(
            id: p[0],
            difficulty: difficulty,
            brand: p[2].isEmpty ? inferredBrand(from: p[3]) : p[2],
            vehicle: p[3],
            mileage: mileage,
            complaint: p[5],
            notes: p[6],
            rootCause: p[7],
            repair: p[8]
        )
    }

    private static func difficulty(from code: String) -> Difficulty? {
        switch code {
        case "E": return .entry
        case "A": return .apprentice
        case "T": return .technician
        case "S": return .senior
        case "M": return .master
        case "D": return .diagnostic
        default: return nil
        }
    }

    private static func makeCase(_ seed: Seed) -> DiagnosticCase {
        let family = family(for: seed)
        let tests = inspections(for: family, seed: seed)
        let tools = Array(Set(tests.map(\.toolID))).map(tool).sorted { toolOrder($0.id) < toolOrder($1.id) }
        let causes = choices(correct: seed.rootCause, wrong: wrongCauses(for: family), prefix: "cause", seedID: seed.id)
        let repairs = choices(correct: seed.repair, wrong: wrongRepairs(for: family), prefix: "repair", seedID: seed.id)

        return DiagnosticCase(
            id: "base44-\(seed.id)",
            difficulty: seed.difficulty,
            brand: seed.brand,
            repairOrder: .init(vehicle: seed.vehicle, mileage: seed.mileage, complaint: seed.complaint, notes: seed.notes),
            tools: tools,
            inspections: tests,
            causes: causes,
            repairs: repairs,
            explanation: explanation(for: family, seed: seed),
            rootCause: seed.rootCause,
            correctRepair: seed.repair,
            takeaways: takeaways(for: family)
        )
    }

    private static func family(for seed: Seed) -> Family {
        let s = (seed.rootCause + " " + seed.repair).lowercased()
        if s.contains("inverter cooling") || s.contains("battery cooling") || s.contains("hybrid cooling") { return .hybridCooling }
        if s.contains("12v") || s.contains("12-volt") || s.contains("battery terminal") || s.contains("battery terminals") { return .battery }
        if s.contains("evap") || s.contains("charcoal") || s.contains("gas cap") || s.contains("fuel filler") { return .evap }
        if s.contains("charge pipe") || s.contains("intake boot") || s.contains("intake duct") || s.contains("vacuum leak") || s.contains("unmetered air") { return .intake }
        if s.contains("cvt") || s.contains("transmission") || s.contains("range sensor") || s.contains("speed sensor") { return .transmission }
        if s.contains("thermostat") || s.contains("water pump") || s.contains("coolant pump") { return .cooling }
        if s.contains("fuel pump") { return .fuel }
        if s.contains("lifter") || s.contains("camshaft") || s.contains("valve train") { return .valvetrain }
        return .ignition
    }

    private static func inspections(for family: Family, seed: Seed) -> [Inspection] {
        func i(_ n: Int, _ view: BayView, _ label: String, _ tool: String, _ productive: Bool, _ finding: String) -> Inspection {
            .init(id: "base44-\(seed.id)-i\(n)", view: view, label: label, toolID: tool, productive: productive, finding: finding)
        }

        switch family {
        case .ignition:
            return [
                i(1,.cockpit,"Stored DTCs / misfire counters","scan_tool",true,"A cylinder-specific misfire is active and the misfire counter rises when the concern occurs."),
                i(2,.underHood,"Affected ignition component","flashlight",true,"Inspection reveals physical/electrical evidence consistent with \(seed.rootCause)."),
                i(3,.underHood,"Coil power and ground","multimeter",false,"Power and ground at the component connector are within specification, ruling out the feed circuit."),
                i(4,.underHood,"Cylinder mechanical condition","pressure_gauge",false,"Cylinder sealing/compression is comparable to neighboring cylinders."),
                i(5,.exterior,"Loaded road test","test_drive",true,"The misfire and power loss reproduce under load and match the affected cylinder data.")
            ]
        case .evap:
            return [
                i(1,.cockpit,"EVAP diagnostic codes","scan_tool",true,"The ECM stores an EVAP leak/control code matching the customer's fuel-vapor complaint."),
                i(2,.underCar,"EVAP smoke test","smoke_machine",true,"Smoke escapes directly from the failed area: \(seed.rootCause)."),
                i(3,.exterior,"Fuel-cap / filler inspection","flashlight",false,"Other visible filler sealing surfaces do not account for the confirmed leak."),
                i(4,.underHood,"Fuel pressure","pressure_gauge",false,"Fuel delivery pressure is within specification, ruling out a liquid-fuel supply fault."),
                i(5,.underHood,"EVAP electrical feed","multimeter",false,"Power and control-side checks do not indicate a separate electrical supply failure.")
            ]
        case .intake:
            return [
                i(1,.cockpit,"Fuel trim / boost DTCs","scan_tool",true,"Lean or underboost data is stored and becomes more pronounced as airflow demand rises."),
                i(2,.underHood,"Intake / charge plumbing","flashlight",true,"A physical defect is visible in the area described by the final diagnosis: \(seed.rootCause)."),
                i(3,.underHood,"Intake smoke test","smoke_machine",true,"Smoke escapes from the failed intake/charge-air connection, proving unmetered air loss."),
                i(4,.underHood,"Fuel pressure","pressure_gauge",false,"Fuel pressure remains in specification, making a supply fault unlikely."),
                i(5,.exterior,"Loaded road test","test_drive",true,"The power-loss/hissing concern reproduces under load and follows boost or fuel-trim deviation.")
            ]
        case .battery:
            let terminalFault = seed.rootCause.lowercased().contains("terminal")
            return [
                i(1,.cockpit,"Module scan / system voltage","scan_tool",true,"Multiple low-voltage or communication faults are present across otherwise unrelated modules."),
                i(2,.underHood,"12-volt battery voltage","multimeter",true, terminalFault ? "System voltage is low under load and voltage drop is concentrated at the battery connection." : "The 12-volt battery voltage is well below normal and collapses further under startup load."),
                i(3,.underHood,"Battery terminals and cables","flashlight",terminalFault,"Visual inspection \(terminalFault ? "shows severe corrosion/high resistance at the connection" : "shows clean, tight cable connections") ."),
                i(4,.underHood,"Main power distribution","test_light",false,"Primary fuses and downstream distribution do not show a separate open circuit."),
                i(5,.underCar,"High-voltage / unrelated systems","flashlight",false,"No physical evidence points to a high-voltage pack or drivetrain failure.")
            ]
        case .transmission:
            let wiring = seed.rootCause.lowercased().contains("wiring") || seed.rootCause.lowercased().contains("sensor")
            return [
                i(1,.cockpit,"Transmission DTCs and live data","scan_tool",true,"Transmission data identifies a pressure, range, speed-signal, or control fault matching the concern."),
                i(2,.underHood,"Transmission harness / fluid condition","flashlight",true, wiring ? "Inspection finds evidence in the range/speed-sensor circuit consistent with \(seed.rootCause)." : "Fluid/physical inspection supports an internal hydraulic or thermal transmission concern."),
                i(3,.underCar,"Hydraulic / circuit verification",wiring ? "multimeter" : "pressure_gauge",true,wiring ? "Electrical testing reproduces the unstable sensor/range signal while the remaining circuit tests normally." : "Hydraulic pressure becomes unstable or falls below specification when the symptom occurs."),
                i(4,.underCar,"Transmission exterior","flashlight",false,"The case and pan have no impact damage or external leak large enough to explain the symptom."),
                i(5,.exterior,"Road test","test_drive",true,"The hesitation, flare, judder, or stall reproduces and correlates with the transmission data fault.")
            ]
        case .cooling:
            return [
                i(1,.cockpit,"Cooling-system DTCs","scan_tool",true,"A thermostat/pump/cooling-system fault is stored and matches the warning shown to the driver."),
                i(2,.underHood,"Cooling component inspection","flashlight",true,"Physical inspection supports the diagnosed failure: \(seed.rootCause)."),
                i(3,.underHood,"Cooling electrical test","multimeter",true,"Power/control is present where required, isolating the fault to the diagnosed component rather than its supply."),
                i(4,.underHood,"Cooling-system pressure","pressure_gauge",seed.rootCause.lowercased().contains("crack"),seed.rootCause.lowercased().contains("crack") ? "Pressure testing reveals leakage at the failed housing." : "The sealed cooling circuit holds pressure, ruling out a major external leak."),
                i(5,.exterior,"Temperature validation","test_drive",true,"Temperature behavior reproduces and confirms inadequate control/circulation from the failed component.")
            ]
        case .fuel:
            return [
                i(1,.cockpit,"Fuel trims / rail-pressure data","scan_tool",true,"Live data shows a lean or low-pressure condition under the same load that produces the complaint."),
                i(2,.underHood,"Fuel pressure under load","pressure_gauge",true,"Fuel pressure drops below specification as demand rises, directly supporting \(seed.rootCause)."),
                i(3,.underHood,"Intake leak check","smoke_machine",false,"The intake tract holds smoke/pressure with no leak large enough to explain the lean condition."),
                i(4,.underHood,"Pump power supply","multimeter",false,"Pump power and ground remain available, ruling out a simple feed-circuit failure."),
                i(5,.exterior,"Loaded road test","test_drive",true,"Power loss/surge occurs at the same moment fuel pressure falls.")
            ]
        case .valvetrain:
            return [
                i(1,.cockpit,"Cylinder misfire data","scan_tool",true,"A specific cylinder misfire is stored and increases at the operating condition described by the customer."),
                i(2,.underHood,"Valve-cover sound localization","stethoscope",true,"A rhythmic mechanical tick is localized to the affected cylinder's valvetrain."),
                i(3,.underHood,"Ignition inspection","flashlight",false,"Ignition components and connections do not show a fault capable of explaining the mechanical noise."),
                i(4,.underHood,"Cylinder sealing / output","pressure_gauge",true,"The affected cylinder shows reduced contribution consistent with impaired valve lift."),
                i(5,.exterior,"Road test","test_drive",true,"The misfire and loss of torque increase with load while the mechanical tick remains synchronized with engine speed.")
            ]
        case .hybridCooling:
            return [
                i(1,.cockpit,"Hybrid-system DTCs / temperatures","scan_tool",true,"Hybrid cooling/performance faults and temperature data rise as the concern appears."),
                i(2,.underHood,"Hybrid cooling hardware","flashlight",true,"Inspection reveals evidence consistent with \(seed.rootCause)."),
                i(3,.underHood,"Cooling fan/pump electrical check","multimeter",true,"Electrical supply is present while the cooling component fails to operate normally."),
                i(4,.underHood,"Noise / operation check","stethoscope",true,"Abnormal or absent component operation is isolated to the failed cooling device."),
                i(5,.exterior,"Thermal road test","test_drive",true,"Power reduction or warning onset correlates with rising hybrid-system temperature.")
            ]
        }
    }

    private static func choices(correct: String, wrong: [String], prefix: String, seedID: String) -> [DiagnosisChoice] {
        let distractors = wrong.filter { $0.caseInsensitiveCompare(correct) != .orderedSame }.prefix(3)
        var result = [DiagnosisChoice(id: "\(seedID)-\(prefix)-correct", text: correct, correct: true)]
        for (idx, text) in distractors.enumerated() {
            result.append(.init(id: "\(seedID)-\(prefix)-\(idx)", text: text, correct: false))
        }
        return result
    }

    private static func wrongCauses(for family: Family) -> [String] {
        switch family {
        case .ignition: return ["Clogged fuel injector", "Internal engine compression failure", "Transmission control fault", "Faulty mass-airflow sensor"]
        case .evap: return ["Weak fuel pump", "Faulty oxygen sensor", "Restricted catalytic converter", "Ignition coil failure"]
        case .intake: return ["High-pressure fuel pump failure", "Faulty mass-airflow sensor", "Restricted catalytic converter", "Transmission slip"]
        case .battery: return ["Failed starter/inverter contactor", "Blown main fuse", "Control-module failure", "High-voltage battery failure"]
        case .transmission: return ["Engine misfire", "Restricted fuel delivery", "Broken engine mount", "Catalytic converter restriction"]
        case .cooling: return ["Blown head gasket", "Cooling fan relay failure", "Coolant temperature sensor fault", "Radiator restriction"]
        case .fuel: return ["Transmission slip", "Boost leak", "Mass-airflow sensor failure", "Catalytic converter restriction"]
        case .valvetrain: return ["Ignition coil failure", "Fuel injector restriction", "Vacuum leak", "Transmission fault"]
        case .hybridCooling: return ["High-voltage battery cell failure", "Traction motor failure", "DC-DC converter failure", "EVAP system fault"]
        }
    }

    private static func wrongRepairs(for family: Family) -> [String] {
        switch family {
        case .ignition: return ["Replace all fuel injectors", "Replace the transmission", "Perform a complete engine rebuild", "Replace the fuel pump"]
        case .evap: return ["Replace the fuel pump", "Replace oxygen sensors", "Replace all fuel injectors", "Replace catalytic converter"]
        case .intake: return ["Replace the high-pressure fuel pump", "Replace the turbocharger", "Replace the MAF without leak testing", "Replace catalytic converter"]
        case .battery: return ["Replace the control module", "Replace the high-voltage battery", "Replace the starter/inverter", "Reprogram the vehicle"]
        case .transmission: return ["Replace ignition coils", "Replace the engine", "Replace the fuel pump", "Replace catalytic converter"]
        case .cooling: return ["Replace the engine", "Replace the cooling fan only", "Replace the radiator without testing", "Replace the ECU"]
        case .fuel: return ["Replace the transmission", "Replace the MAF sensor", "Replace catalytic converter", "Replace ignition coils"]
        case .valvetrain: return ["Replace ignition coil only", "Replace the fuel pump", "Clean the injectors", "Replace the transmission"]
        case .hybridCooling: return ["Replace the traction battery", "Replace the traction motor", "Replace the inverter assembly", "Replace the engine cooling radiator"]
        }
    }

    private static func explanation(for family: Family, seed: Seed) -> String {
        let lead: String
        switch family {
        case .ignition: lead = "Cylinder-specific scan data plus component and circuit testing isolates the misfire source."
        case .evap: lead = "The EVAP code identifies the system and smoke testing physically locates the vapor leak."
        case .intake: lead = "Lean/underboost data combined with a visual and smoke-confirmed air leak proves the intake fault."
        case .battery: lead = "Low system voltage under load explains the clicking, flickering, communication faults, or no-start behavior."
        case .transmission: lead = "Transmission live data plus circuit/hydraulic testing correlates the drivability symptom with the transmission fault."
        case .cooling: lead = "Cooling-system codes, electrical checks, and temperature/pressure behavior isolate the failed cooling component."
        case .fuel: lead = "Fuel pressure falls under load while other air-path checks remain normal, proving a delivery problem."
        case .valvetrain: lead = "The misfire follows a localized mechanical valvetrain noise and reduced cylinder contribution rather than an ignition fault."
        case .hybridCooling: lead = "Hybrid temperature data and direct component testing show the thermal-management system cannot maintain temperature."
        }
        return "\(lead) The original Base44 case's verified root cause was \(seed.rootCause), with the correct repair: \(seed.repair)."
    }

    private static func takeaways(for family: Family) -> [String] {
        switch family {
        case .ignition: return ["Use the DTC to identify a direction, then prove the component before replacing it.", "A flashing check-engine light usually means an active catalyst-damaging misfire."]
        case .evap: return ["Smoke testing is the fastest way to turn an invisible vapor leak into visible evidence.", "Do not assume every EVAP code is a gas cap."]
        case .intake: return ["Lean and underboost faults often come from unmetered air, not an expensive sensor.", "Pressure/smoke testing should precede turbo or fuel-system replacement."]
        case .battery: return ["Verify base system voltage before chasing module faults.", "Low voltage can create many unrelated communication codes at once."]
        case .transmission: return ["Correlate scan data with hydraulic/electrical evidence before condemning the whole transmission.", "A drivability description such as shudder or slip does not prove internal hard-part failure."]
        case .cooling: return ["Verify power, pressure, and component operation before replacing cooling parts.", "Fail-safe fan operation may be a reaction to another cooling-system fault."]
        case .fuel: return ["Fuel pressure must be checked under the load where the symptom occurs.", "A normal idle pressure reading can hide a pump that cannot maintain volume."]
        case .valvetrain: return ["Correlate cylinder misfire data with localized mechanical noise.", "Do not keep replacing ignition parts when the evidence points to loss of valve lift."]
        case .hybridCooling: return ["Hybrid power electronics depend on dedicated thermal-management systems.", "Temperature correlation can separate cooling failure from traction-component failure."]
        }
    }

    private static func tool(_ id: String) -> DiagnosticTool {
        let symbol: String
        let name: String
        let hint: String
        switch id {
        case "scan_tool": symbol="waveform.path.ecg.rectangle"; name="Diagnostic Scan Tool"; hint="Read DTCs, module data and live PIDs."
        case "flashlight": symbol="flashlight.on.fill"; name="Inspection Light"; hint="Inspect visible components, wiring, leaks and damage."
        case "multimeter": symbol="gauge.with.dots.needle.33percent"; name="Digital Multimeter"; hint="Measure voltage, resistance and continuity."
        case "test_light": symbol="lightbulb.fill"; name="Test Light"; hint="Quickly verify whether power is present in a circuit."
        case "pressure_gauge": symbol="gauge.open.with.lines.needle.33percent"; name="Pressure Gauge"; hint="Measure fuel, compression, cooling or hydraulic pressure."
        case "stethoscope": symbol="ear.fill"; name="Mechanic's Stethoscope"; hint="Pinpoint mechanical noises and component operation."
        case "smoke_machine": symbol="aqi.medium"; name="Smoke Machine"; hint="Locate intake, boost and EVAP leaks."
        case "test_drive": symbol="road.lanes"; name="Road Test"; hint="Reproduce the concern under operating load."
        default: symbol="wrench.and.screwdriver.fill"; name=id.replacingOccurrences(of:"_",with:" ").capitalized; hint="Gather diagnostic evidence."
        }
        return .init(id:id,name:name,symbol:symbol,hint:hint)
    }

    private static func toolOrder(_ id: String) -> Int {
        ["scan_tool","flashlight","multimeter","test_light","pressure_gauge","stethoscope","smoke_machine","test_drive"].firstIndex(of:id) ?? 99
    }

    private static func inferredBrand(from vehicle: String) -> String? {
        let s = vehicle.lowercased()
        if s.contains("nisshin") { return "Nisshin Motors" }
        if s.contains("stellar") || s.contains("smc") { return "Stellar Motors Corp" }
        if s.contains("bayern") { return "Bayern Werke" }
        if s.contains("kestrel") { return "Kestrel Automotive" }
        if s.contains("aeon") { return "Aeon Mobility" }
        return nil
    }

    // id ¦ difficulty(E/A/T/S/M/D) ¦ explicit brand ¦ vehicle ¦ mileage ¦ complaint ¦ writer notes ¦ verified root cause ¦ verified repair
    private static let rawSeeds = """
6aa0401e0d98b47da6c3e54d¦A¦¦2019 SMC Zenith LT¦84500¦Check engine light is on and the engine stumbles or misfires at highway speed, especially under light acceleration.¦Concern is more noticeable on hills; no recent engine work.¦Ignition Coil Failure¦Replace Ignition Coil #1 and Spark Plug #1
6a9ed5c40100e6d847840d83¦E¦¦2019 SMC Voyager LX¦82450¦Check engine light is on and there is a strong raw-gasoline smell around the rear of the vehicle.¦Light came on yesterday; fuel-cap tightness appears normal.¦Cracked charcoal canister causing an EVAP system leak¦Remove and replace the charcoal canister assembly
6a9ed2349fb4f901bbeb0914¦E¦¦2018 Nisshin Kaze LX¦94500¦Car loses power when accelerating and the Service Engine Soon light came on this morning.¦Concern began after a long commute; vehicle had not yet been scanned.¦Vacuum leak due to a cracked rubber air intake boot¦Replace the damaged air intake boot with an OEM unit
6a9ed041c228ef1d252e79ac¦E¦¦2019 SMC Meridian LT¦82450¦Check engine light is on and there is a gasoline smell around the back of the car while idling.¦Light appeared shortly after a fill-up; no driveability concern reported.¦Cracked EVAP system vapor hose¦Replace the damaged EVAP vapor hose
6a9ec52ea8ae04afe633fbf8¦E¦¦2018 Bayern Werke L6-330i xDrive¦68420¦Vehicle loses power and shows a yellow engine light; acceleration feels like the engine is gasping for air.¦Intermittent power loss under load; no obvious external leaks.¦Torn charge pipe gasket at the throttle body¦Replace the throttle body gasket and secure the charge pipe
6a9e41afeeb31209388f1bfb¦E¦¦2018 Nisshin Kestrel LX-S¦82450¦The car has very little power on the highway and the check engine light sometimes flashes.¦Concern occurs mostly at highway speed and did not reproduce on a short lot drive.¦Failed ignition coil on cylinder 3 causing an engine misfire¦Replace the cylinder 3 ignition coil and clear the stored trouble code
6a9e235be23378b2dd75302e¦E¦¦2021 Stellar Motors Corp (SMC) Meridian SUV¦68450¦Check engine light is on and a hissing sound comes from the engine bay while idling.¦Light appeared suddenly on the highway; CEL is currently active.¦Internal diaphragm failure within the EVAP purge control valve¦Replace the faulty EVAP purge control valve assembly
6a9e2351a49242700b5bfe37¦E¦¦2019 Kestrel Talon Sport¦58400¦The engine runs very rough and the check engine light flashes; the vehicle shakes badly at stoplights.¦Shaking is constant at idle and is present in the bay.¦Failed Cylinder 3 Ignition Coil¦Replace the faulty ignition coil and spark plug
6a9e20fae200d376b9e6d74a¦E¦¦2017 Nisshin Zenith LE 2.5L¦88450¦The car has no power under acceleration, the engine light flashes, and the vehicle feels jerky.¦Condition is constant at all speeds; vehicle recently had a routine oil change.¦Failed ignition coil pack on cylinder 3¦Replace the cylinder 3 ignition coil
6a9e207ed8ae0847836f4531¦E¦¦2018 Nisshin Kaze LX¦94500¦The car feels sluggish and vibrates during acceleration, and the Check Engine light came on.¦Concern began suddenly during the commute and did not reproduce on a brief lot drive.¦Failed ignition coil on cylinder 3¦Replace ignition coil #3
6a9e2070053fc4d565601972¦E¦¦Aeon Mobility Flux EV 2021 LE¦42500¦The car will not start and displays Check Hybrid System; it is completely dead when the start button is pressed.¦Vehicle arrived by tow truck and had operated normally the previous evening.¦Failed 12V auxiliary battery¦Replace the 12V auxiliary battery
6a9e206d8ddcd222bacd7c1f¦E¦¦2018 Nisshin Kaze LX¦74520¦The car shakes badly when accelerating from a stop and feels like the transmission is slipping or shuddering.¦Condition has worsened over the last week.¦Failed CVT valve body assembly¦Replace the CVT valve body and perform the relearn procedure
6a9e20527435a8189452fd69¦E¦¦2018 Stellar Motors Corp (SMC) Meridian LX¦82450¦Check engine light is on, idle is rough, and there is a hissing sound from the engine bay.¦Light appeared after fueling at a new station.¦Cracked EVAP vacuum hose¦Replace the damaged EVAP vacuum line
6a9e204c3b51e0e2d5f20ab4¦E¦¦2017 Nisshin Zenith LE 4-Door Sedan¦82450¦The car has little power leaving stoplights and sometimes the engine light flashes while it shakes under throttle.¦Concern is consistent at low speed; no current ignition-service records.¦Failed Cylinder 2 Ignition Coil¦Replace the Cylinder 2 Ignition Coil
6a9e1fecd6a17f31fdd5272f¦E¦¦2021 Aeon Mobility Flux SE¦42150¦The car will not start in the morning; the dash flickers, everything goes dead, and there is rapid clicking.¦Happens mostly after sitting overnight; dash flicker was verified.¦Dead 12V auxiliary battery¦Replace the 12V auxiliary battery
6a9e1fbf3829e1f8dacee308¦E¦¦2021 Aeon Mobility Flux Hybrid SEL¦42150¦The car will not start; warning lights flicker and a faint clicking sound is heard when the start button is pressed.¦A jump-start attempt was unsuccessful.¦Failed 12V auxiliary battery due to internal cell degradation¦Replace the 12V auxiliary battery and clear low-voltage DTCs
6a9e1f4e8f3e065f391dbb8c¦E¦¦Aeon Mobility Flux EV 2021 Base Trim¦42150¦The car will not start and displays multiple power-system warnings; it is dead when the start button is pressed.¦This is the third failure this week; a jump start temporarily fixed it yesterday.¦Failed 12V auxiliary battery¦Install a new 12V auxiliary battery
6a9e1f4bdc3c24fbedc55670¦E¦¦2019 Stellar Motors Corp (SMC) Meridian SUV SLE¦82450¦Check engine light is on and gasoline can be smelled near the rear of the vehicle.¦No liquid puddles were found during check-in.¦Damaged charcoal canister and deteriorated EVAP vent hose¦Replace the charcoal canister and cracked vent hose assembly
6a9e1eddb990cb4426884dbc¦E¦¦2018 SMC Titan-V8 Crew Cab¦82450¦Check engine light is on and there is a strong gasoline smell near the tank when parked in the garage.¦Light appeared after filling up; odor was not present during lot check.¦Cracked EVAP vapor line¦Replace the cracked EVAP vapor hose
6a9e1ebdf85080554c61df12¦E¦¦2018 Bayern Werke X5-Sport L6¦68420¦The car loses power on the highway and the check engine light comes on; it feels starved for fuel under acceleration.¦Power loss happens mostly at highway speed and was not active on the lot.¦Worn High Pressure Fuel Pump (HPFP)¦Replace the High Pressure Fuel Pump
6a9e1e9d900f69944dfb74a5¦E¦¦2018 Nisshin Kaze LX¦94250¦The car struggles to pick up speed, shakes while driving, and has a check engine light.¦Concern started suddenly on the morning commute.¦CVT Valve Body and Solenoid Failure¦Replace the transmission valve body and perform a fluid replacement
6a9e1e7cbd1adb5ddaa84038¦E¦¦2017 Nisshin Sora LE¦94200¦The car loses power during acceleration and the Service Engine Soon lamp is on.¦Concern is strongest when pulling away from stop signs.¦Torn air intake boot allowing unmetered air into the engine¦Replace the damaged air intake boot
6a9e1e768a00d5132218b682¦E¦¦2018 Nisshin Kaze Sedan Sport¦94200¦The car shakes badly at stoplights and the engine feels like it is jumping around; the Service Engine Soon lamp is on.¦First occurrence; idle feels slightly uneven in the service drive.¦Defective cylinder 3 ignition coil pack¦Replace the damaged ignition coil pack on cylinder 3
6a9e1dc63f164eaa308a44c2¦E¦¦2019 Stellar Motors Corp (SMC) Zenith V8¦82450¦Check engine light is on and a faint gas smell is present near the rear after filling up.¦Concern began shortly after the last fill-up.¦Leaking EVAP System Hose¦Replace the damaged EVAP rubber hose
6a9e17dac25fa1ec101a026c¦E¦Nisshin Motors¦2018 Nisshin Sentier SV 4-cylinder¦82450¦The car is sluggish, the Check Engine light keeps returning, and it stutters while accelerating from a stop.¦Concern is more prominent at normal operating temperature.¦Torn/cracked air intake duct hose¦Replace the intake air duct hose
6a9e15fab68f03f58dfa732a¦E¦¦2021 Aeon Mobility Flux Hybrid - LE Trim¦42560¦The car will not start in the morning; the dash is black and it clicks when the start button is pressed.¦Vehicle required a jump start to reach the shop; terminals appear clean.¦Failed 12V Auxiliary Battery¦Replace the 12V Auxiliary Battery
6a9e15ba739ebcbe00840d13¦E¦¦2018 Bayern Werke L6-Series xDrive Sedan¦62450¦Check engine light is on; highway acceleration is weak and a loud rushing/hissing noise occurs under heavy throttle.¦Noise is most noticeable during heavy throttle; no fluid leaks seen.¦Split/Cracked Charge Pipe¦Replace Cracked Charge Pipe
6a9e15b733f899f73258f30e¦E¦¦2018 Nisshin Kaze LX¦94500¦The car shakes badly at highway speed and the check engine light flashes, especially during acceleration.¦Concern is consistent between 55-65 mph; vehicle recently had an oil change.¦Failed ignition coil on cylinder 3¦Replace the cylinder 3 ignition coil
6a9e15a8e2531fcd846bdb2d¦E¦¦2018 Kestrel Automotive Skyhawk LX¦82450¦The car has a flashing check engine light and shakes badly when accelerating from a stop.¦Shaking started suddenly this morning and did not reproduce in the parking lot.¦Failed Cylinder 3 Ignition Coil¦Replace Ignition Coil Pack for Cylinder 3
6a9e133a525c2e286d764fd3¦E¦¦2018 Nisshin Kaze LX¦94200¦The car is sluggish and jerks from a stop; the Service Engine Soon light just came on.¦Concern began yesterday and was not duplicated on a short lot drive.¦Damaged Transmission Range Sensor Wiring Harness¦Clean and repair the transmission wiring harness
6a9e132dad591fa6baa126e7¦E¦¦2019 Stellar Motors Corp (SMC) Apex V8 Sedan¦82450¦Check engine light is on and there is a strong raw-gas smell near the rear when parked.¦Odor is most noticeable after filling the tank; no puddles seen.¦Cracked EVAP system charcoal canister hose¦Replace the damaged EVAP charcoal canister hose
6a9e132b50f78d5a0c88884d¦E¦¦2018 Bayern Werke 330i Sport¦62450¦The car overheats and displays a Coolant Pump Malfunction warning shortly after startup.¦Customer pulled over immediately; no visible coolant leak on the floor.¦Failed Electric Coolant Pump internal motor¦Replace the electric water pump and perform the coolant bleeding procedure
6a9e1327068322f1b99b23ea¦E¦¦2017 Nisshin Zenith LE 4-Door Sedan¦82450¦The car has no power when pulling away from a stop and the check engine light is on.¦Concern happens every drive; no previous engine work noted.¦Clogged fuel pump strainer/failing fuel pump¦Replace the in-tank fuel pump assembly
6a9e12d45036da94a5c3ecc5¦E¦¦2018 Stellar Motors Corp (SMC) Apex V8 Sedan¦82450¦Check engine light is on and there is a strong raw-gas smell around the rear after driving.¦Light appeared shortly after filling the tank.¦Cracked EVAP system hose near the fuel tank¦Replace the damaged EVAP purge hose assembly
6a9e1292fe14d192a827fd9d¦E¦¦2018 Bayern Werke 330i Sport¦82450¦The car is overheating, the dash says Engine Temperature Too High, and the cooling fan runs constantly at high speed.¦Concern began suddenly during the morning commute.¦Failed Electric Thermostat¦Replace the Engine Coolant Thermostat
6a9e128e49ff56e399e2dee6¦E¦¦2018 Bayern Werke 340i Sport¦72450¦The engine light is on, highway acceleration is extremely weak, and a hissing noise occurs under throttle.¦Concern began yesterday and is not obvious at idle.¦Split plastic charge pipe causing a boost pressure leak¦Replace the charge pipe assembly
6a9e1285749f47685649d2a3¦E¦¦2021 Aeon Mobility Flux Hybrid Sedan¦42500¦The car will not start in the morning; dash lights flicker and then everything goes dead.¦This has happened twice this week; battery may have been weak during a cold snap.¦Failed 12V auxiliary battery¦Replace the 12V auxiliary battery
6a9e12730c8aa9fabc6191fc¦E¦¦2019 Kestrel Talon Sport¦68420¦The engine runs rough and the check engine light flashes during hard acceleration; it feels like it misses beats.¦Concern started suddenly yesterday and was not duplicated in the parking lot.¦Cylinder 3 Ignition Coil failure¦Replace the ignition coil for cylinder 3
6a9e123fdfa8d97453a2f29b¦E¦¦2021 Aeon Mobility Flux Hybrid Premium¦42500¦The car will not start; dash lights dim and there is a faint clicking sound when the start button is pressed.¦A jump start worked last week for a few days; battery appears original.¦Failed 12V auxiliary battery¦Replace the 12V auxiliary battery
6a9e1207a03c1c2e8e3128b7¦E¦¦2019 Kestrel Talon Sport¦64200¦Check engine light is on and the car stutters under light load at highway speed.¦Concern happens mostly at steady highway speed; CEL is verified on.¦Faulty Ignition Coil on Cylinder 3¦Replace Ignition Coil 3
6a9e11ff51ad9c5d9d505e78¦E¦¦2018 Nisshin Kaze LX¦92450¦The car jerks and surges during acceleration and the yellow engine warning light is on.¦Concern is most noticeable at highway speed; no service in more than 15,000 miles.¦Faulty CVT Valve Body Assembly¦Replace the transmission valve body and perform a fluid flush
6a9e11e96277396b36282a54¦E¦¦2018 Bayern Werke 340i Sport¦62450¦The car is sluggish and the engine light comes on during hard highway acceleration.¦Fault history was previously cleared but the light returned.¦Cracked charge pipe causing a boost leak¦Replace the cracked plastic charge pipe
6a9e11ddb192964dc3489512¦E¦¦2018 Bayern Werke X5-Sport Sedan¦82450¦The car runs rough, lacks power, and the check engine light came on during highway driving.¦Engine vibration is most noticeable during acceleration; light remains steady.¦Failed Cylinder 3 Ignition Coil¦Replace ignition coil on cylinder 3
6a9e11cd68f5af3b334465e7¦E¦¦Aeon Mobility Flux EV, 2021 Base Trim¦42150¦The car will not start; warning lights flicker and electronics cycle before the dash goes black.¦Vehicle sat overnight; attempted boost was unsuccessful.¦Failed 12V auxiliary battery¦Replace 12V auxiliary battery
6a9e11cb758d9394dce5bb64¦E¦¦2018 SMC Zenith V8 SLE¦94200¦Check engine light is on and the vehicle stutters at idle as if it may stall.¦Concern is consistent with no other driveability complaint.¦Vacuum leak due to a cracked intake hose¦Replace the damaged vacuum hose and clear the ECM fault code
6a9e116ac9c011fa80fce0f3¦E¦¦2019 Kestrel Talon Sport¦64200¦The car runs rough and the check engine light came on during highway acceleration; it shakes under load.¦Concern is most prominent under load; no prior engine work documented.¦Cracked ignition coil on cylinder 3¦Replace ignition coil unit for cylinder 3
6a9e114b790e35ab08c2da5c¦E¦¦2019 Kestrel Talon Sport¦62450¦The engine suddenly began running rough and the check engine light came on; it shakes at stoplights.¦Concern started during the morning commute.¦Failed Ignition Coil on Cylinder 3¦Replace Ignition Coil for Cylinder 3
6a9e110b750973abbd6a9ce2¦T¦¦Aeon Mobility Voltura Hybrid 2021¦78450¦Check Hybrid System is on, there is a loud front whine, and power drops during highway acceleration.¦Intermittent after about 20 minutes of driving; noise is loudest when the gas engine engages.¦Failed electric inverter cooling pump¦Replace inverter cooling pump and refill/bleed the hybrid cooling system
6a9e10d3e4243a6391b55be0¦E¦¦2018 Bayern Werke X5-Sport L6¦68420¦The car is sluggish, the engine light is on, and a loud whooshing sound occurs during highway acceleration.¦Concern began suddenly yesterday; no previous boost issues.¦Split/Cracked Turbocharger Charge Pipe¦Replace the damaged intake charge pipe
6a9e0d05d88dfe6aa9e7aff3¦E¦¦2019 Stellar Motors Corp (SMC) Meridian SUV LX¦82450¦The check engine light is on and the engine struggles to stay running at stoplights with a rough idle.¦Concern is consistent; no unusual noises reported.¦Failed EVAP Purge Control Valve¦Replace the EVAP Purge Control Valve unit
6a9e0c45ec95f8733c521c14¦T¦¦2018 Stellar Motors Corp (SMC) Sentinel V8¦92450¦There is a rhythmic ticking from the passenger side when warm, the Check Engine light is on, and acceleration feels slightly weak.¦Concern began after a long road trip and was not present on cold start.¦Failed hydraulic valve lifter on cylinder 4¦Replace the cylinder 4 lifter and inspect the camshaft lobe
6a9e0c2483fb0131832dbb82¦E¦¦2018 Nisshin Kaze LX¦94200¦The transmission feels like it is slipping during acceleration and the check engine light came on.¦Concern began after a long highway commute; no transmission service to date.¦CVT Valve Body failure¦Replace the CVT valve body and perform a transmission fluid flush
6a9e0c114f50637ba1847ebf¦A¦¦2019 Aeon Mobility Zenith Hybrid, Luxury Trim¦82450¦The dash shows System Fault and a very loud cooling fan sometimes runs after the vehicle is parked.¦Concern began after a long highway trip; fan noise was not duplicated on the lot.¦Failed high-voltage battery cooling fan motor due to debris ingestion¦Clear the cooling duct and replace the battery cooling fan motor
6a9e0c07422a004e0ed64a94¦E¦¦2021 SMC Vanguard LTZ¦82450¦Check engine light is on and the car sometimes smells like raw gasoline after parking.¦Fuel odor is intermittent; no leak was obvious on the service drive.¦Cracked Fuel Filler Hose¦Replace Fuel Filler Neck Hose
6a9e0c05079d147d9159858d¦E¦¦2018 Nisshin Kaze LX¦94205¦The car is sluggish, vibrates at stoplights, and the Service Engine Soon light is on.¦Concern began suddenly after filling at a budget gas station.¦Failed ignition coil on cylinder 3 causing a persistent misfire¦Replace Ignition Coil on Cylinder 3
6a9e0bcaa03c1c2e8e2fc707¦E¦¦2018 Bayern Werke X5-e 3.0i Premium¦72450¦The car reports overheating and the radiator fan runs loudly at full speed as soon as the engine starts.¦Condition is now constant; no previous cooling repairs.¦Failed electronic thermostat assembly¦Replace the thermostat housing assembly
6a9e0b9bf3ba5f12a96639ce¦E¦¦2019 Stellar Motors Corp (SMC) Zenith V8¦82450¦Check engine light is on and there is a gas smell near the rear after filling up.¦Customer recently replaced the air filter; no other recent service.¦Damaged gas cap seal causing an EVAP system leak¦Replace the gas cap with a new OEM-spec unit
6a9e0b88ba536cd0f0f18403¦E¦¦2017 Nisshin Altura S¦94200¦The car loses power when accelerating and the Service Engine Soon light just came on.¦Concern began suddenly this morning and was not duplicated on the lot.¦Failed Cylinder 2 Ignition Coil¦Replace the Cylinder 2 Ignition Coil
6a9e0b763b73db77277a955d¦E¦¦2018 Stellar Motors Corp (SMC) Meridian Limited¦82450¦Check engine light is on and there is a raw-gas smell while idling at a stoplight.¦Odor is most noticeable after the engine reaches operating temperature.¦Failed EVAP purge control valve¦Replace EVAP purge control valve
6a9e0b72747a625e4720dedf¦M¦¦2017 Nisshin Apex-S (Sedan)¦98450¦The car randomly drags or surges during highway acceleration and sometimes vibrates; no warning lights are on.¦No check engine light has illuminated; no obvious leaks seen.¦In-tank electric fuel pump assembly failure¦Replace in-tank fuel pump and integrated filter module
6a9e0b53ecf279cbd0a564cf¦E¦¦2016 Bayern Werke 330i Sport¦84200¦The car is sluggish, the check engine light is on, and a loud hissing sound occurs during hard acceleration.¦Vehicle runs normally at idle but bogs under load.¦Ruptured plastic charge pipe¦Replace the charge pipe assembly
6a9e0b48f5f8b5ad7b3a0d97¦E¦¦2016 Nisshin Motors Sentara SV¦94200¦The car loses power pulling away from a stop; RPM rises but vehicle speed does not increase normally.¦Concern is consistent once warm; no warning light reported.¦Overheated CVT fluid and restricted transmission cooler airflow¦Flush CVT fluid and clean/replace the transmission cooler
6a9e08e931e522cd85698c32¦E¦¦2019 Kestrel Automotive Talon GT¦62450¦The car shakes badly accelerating from a stop, especially cold; the check engine light flashes.¦Shudder is worst cold and an active misfire was observed.¦Failed Ignition Coil on Cylinder 3¦Replace Cylinder 3 Ignition Coil and inspect spark plug
6a9e08c560d26a9a135456e7¦E¦¦2021 Aeon Mobility Flux-S Hybrid¦42500¦The car will not start; multiple warnings appear and the dashboard behaves erratically.¦Vehicle operated normally yesterday; an interior light may have been left on.¦Depleted 12V auxiliary battery¦Replace the 12V auxiliary battery
6a9e08bfe0bedb9863fd345a¦E¦¦2018 Stellar Motors Corp (SMC) Apex GT¦82450¦Check engine light is on and the engine runs rough at idle, shaking at stoplights.¦Concern began after a long highway trip; idle oscillation was confirmed.¦Failed lifter and wiped cam lobe on cylinder 5 due to cylinder deactivation failure¦Replace the faulty hydraulic lifter and camshaft on the affected bank
6a9e08b4913557b0c9d03fb4¦E¦¦2018 Kestrel Automotive Skyhawk GT¦78420¦The car runs very rough, the check engine light flashes, and it shakes at stoplights.¦Concern began after a long highway drive and was intermittent at check-in.¦Failed Cylinder 3 Ignition Coil¦Replace the Cylinder 3 Ignition Coil
6a9e087906678a208f975d99¦E¦¦2016 Nisshin Motors Altura SV¦92450¦The car stalls when coming to stops, shudders just before dying, and restarts normally.¦Concern occurs hot or cold; a slight stumble was noticed when shifting into gear.¦Corroded/damaged wiring harness for the CVT input speed sensor¦Repair or replace the damaged speed sensor wiring harness and clear stored error codes
6a9e0828575bb20a4e9bdcfd¦E¦¦2016 Nisshin Sentra SV¦94200¦The car shakes while accelerating from a stop and feels like it struggles to get moving; Service Engine Soon is on.¦Shaking is worse when fully warmed up; no obvious external transmission leak.¦Transmission valve body failure¦Replace the transmission valve body
6a9dd6bd803c8eaa55d483bf¦E¦¦2016 Bayern Werke 335i Sedan¦84500¦The car is sluggish, has a loud hissing noise under hard acceleration, and the check engine light is on.¦Concern occurs mainly under heavy throttle and cannot be duplicated while stationary.¦Cracked plastic intake charge pipe¦Replace the damaged charge pipe with a new unit
6a9dd60a778fefcc3a0e635a¦E¦¦2021 Aeon Mobility Solara EV Premium¦42500¦The car will not start; dash lights flicker rapidly, errors appear, and then the screen goes black.¦Vehicle sat for four days and a jump-start attempt did not solve it.¦Failed 12V auxiliary battery due to internal cell depletion¦Replace the 12V auxiliary battery with an OEM-spec unit
6a9dd5dff38bbeb581b24875¦E¦¦2016 Nisshin Sentura SV¦82450¦The car will not start after parking; it only clicks and the dashboard lights flicker wildly.¦Battery is about four years old.¦Severely corroded battery terminals and low state of charge¦Clean battery terminals and perform a slow charge/load test
6a9dd5caf6e8b97130bd3e0b¦E¦¦2016 Bayern Werke 335i Sport Line¦84500¦The car overheats, the cooling fan is very loud, and a low-coolant warning is on.¦Concern began during city driving; no leak was obvious on the shop floor.¦Cracked plastic thermostat housing¦Replace the thermostat housing and flush coolant
6a9dd5c95544ddbbf89d28e1¦E¦¦2019 Kestrel Automotive Talon GT Turbo¦72450¦Check engine light came on after the engine began running rough at stoplights; it shakes at idle.¦Light flashed while accelerating from a stop; heavy misfire was verified.¦Ignition coil for cylinder 3 had internal insulation breakdown¦Replace the failed cylinder 3 ignition coil and spark plug
6a9dd5c48a522feaa57cebf1¦E¦¦2018 Stellar Motors Corp (SMC) Apex V8 Sedan¦94200¦Check engine light is on and the car runs rough at idle, shaking while stopped in drive.¦Vibration is worse when fully warm.¦Collapsed hydraulic valve lifter causing valve train failure on cylinder 3¦Replace the failed hydraulic lifter and inspect the camshaft lobe
6a9dd5b6a6075fc954b24b0b¦E¦¦2018 SMC Titan V8 Crew Cab¦94200¦Check engine light is on, the truck sometimes stalls at stops, and raw fuel can be smelled near the rear.¦Concern began after the last fill-up; no prior fuel-system repairs.¦Failed EVAP Vent Valve assembly¦Replace the EVAP Vent Valve assembly near the fuel tank
6a9dd5983691e5099faffee8¦E¦¦2016 Bayern Werke 330i Sport¦84250¦The car is sluggish, the check engine light is on, and a rushing/hissing sound occurs at highway speed.¦Quick scan already showed a Bank 1 lean condition.¦Cracked intake charge pipe leading to a boost leak¦Replace the damaged plastic intake charge pipe
6a9dd586b83c5f239668150b¦E¦¦2019 Kestrel Apex Sport¦68420¦The engine runs very rough, the check engine light flashes, and the car has little power.¦Concern began suddenly this morning and the vehicle shook violently at intake.¦Failed Ignition Coil on Cylinder 3¦Replace ignition coil assembly for cylinder 3
6a9dd57a89ede11cf1c2c703¦E¦¦2018 Stellar Motors Corp (SMC) Titan V8 Crew Cab¦94200¦Check engine light is constantly on and the truck stumbles at idle as if it may stall.¦Concern is constant; current trouble codes should be verified first.¦Split/Cracked rubber air intake boot¦Replace the damaged air intake boot assembly
6a9dd568aea455fefbb23c44¦E¦¦2018 Stellar Motors Corp (SMC) Titan V8 Crew Cab¦94200¦Check engine light is on and the vehicle hesitates or stutters while cruising at steady speed.¦Concern began after a long trip; customer requested a full diagnostic report.¦Compromised EVAP system integrity due to cracked hoses and failed gas cap seal¦Replace cracked EVAP rubber hoses and install a new OEM gas cap
6a9dd52eecf23e9f233ea484¦E¦Nisshin Motors¦2016 Nisshin Motors Sentra SV¦98450¦The car feels sluggish and jerks when accelerating, especially at low speed; the check engine light came on this morning.¦Concern is more frequent once the engine reaches operating temperature.¦Faulty Transmission Range Sensor¦Replace the Transmission Range Sensor assembly
"""
}
