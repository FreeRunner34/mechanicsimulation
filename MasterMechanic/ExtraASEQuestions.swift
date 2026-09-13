import Foundation

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
