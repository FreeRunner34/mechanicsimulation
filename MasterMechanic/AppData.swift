import Foundation
import Combine

@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var points: Int
    @Published private(set) var completedCases: Int
    @Published private(set) var correctCases: Int
    @Published private(set) var streak: Int
    @Published private(set) var lastScore: Int
    private let defaults = UserDefaults.standard

    init() {
        points = defaults.integer(forKey: "progress.points")
        completedCases = defaults.integer(forKey: "progress.completed")
        correctCases = defaults.integer(forKey: "progress.correct")
        streak = defaults.integer(forKey: "progress.streak")
        lastScore = defaults.integer(forKey: "progress.lastScore")
    }

    var accuracy: Int { completedCases == 0 ? 0 : Int((Double(correctCases) / Double(completedCases) * 100).rounded()) }
    var rank: String {
        switch points {
        case 0..<500: "Lube Tech"
        case 500..<1500: "Apprentice"
        case 1500..<3500: "Line Technician"
        case 3500..<7000: "Senior Technician"
        case 7000..<12000: "Master Technician"
        default: "Diagnostic Specialist"
        }
    }

    func record(score: Int, solved: Bool) {
        completedCases += 1; correctCases += solved ? 1 : 0; streak = solved ? streak + 1 : 0
        lastScore = score; points += max(0, score); persist()
    }
    func reset() { points = 0; completedCases = 0; correctCases = 0; streak = 0; lastScore = 0; persist() }
    private func persist() {
        defaults.set(points, forKey: "progress.points"); defaults.set(completedCases, forKey: "progress.completed")
        defaults.set(correctCases, forKey: "progress.correct"); defaults.set(streak, forKey: "progress.streak")
        defaults.set(lastScore, forKey: "progress.lastScore")
    }
}

struct AppData {
    static let shared = AppData()
    let tools: [DiagnosticTool] = [
        .init(id:"flashlight", name:"Inspection Light", symbol:"flashlight.on.fill", hint:"Visual inspection of leaks, wiring, wear and damage."),
        .init(id:"scan_tool", name:"Scan Tool", symbol:"waveform.path.ecg.rectangle", hint:"Read DTCs, freeze-frame and live data."),
        .init(id:"multimeter", name:"Digital Multimeter", symbol:"gauge.with.dots.needle.33percent", hint:"Check voltage, resistance and voltage drop."),
        .init(id:"pressure_gauge", name:"Pressure Gauge", symbol:"gauge.open.with.lines.needle.33percent", hint:"Measure fuel, compression and hydraulic pressure."),
        .init(id:"stethoscope", name:"Stethoscope", symbol:"ear.fill", hint:"Pinpoint mechanical noises and injector activity."),
        .init(id:"smoke_machine", name:"Smoke Machine", symbol:"aqi.medium", hint:"Locate intake and EVAP leaks."),
        .init(id:"test_drive", name:"Road Test", symbol:"road.lanes", hint:"Reproduce the concern under load.")
    ]
    var toolReferences: [ToolReference] { tools.map { .init(id:$0.id, name:$0.name, symbol:$0.symbol, use:$0.hint, tip:"Use the least invasive test that can prove or eliminate a theory.") } }
    let cases: [DiagnosticCase]
    let aseQuestions: [ASEQuestion]

    init() {
        func t(_ id:String) -> DiagnosticTool { tools.first { $0.id == id }! }
        func i(_ id:String,_ view:BayView,_ label:String,_ tool:String,_ productive:Bool,_ finding:String) -> Inspection { .init(id:id, view:view, label:label, toolID:tool, productive:productive, finding:finding) }
        func c(_ id:String,_ text:String,_ correct:Bool=false) -> DiagnosisChoice { .init(id:id, text:text, correct:correct) }

        cases = [
            .init(id:"entry-battery", difficulty:.entry, brand:nil,
                  repairOrder:.init(vehicle:"2018 Kestrel Vector 2.0", mileage:71220, complaint:"Single click when starting in the morning; lights look normal.", notes:"Jump-started once last week."),
                  tools:[t("flashlight"),t("multimeter")],
                  inspections:[i("e1",.underHood,"Battery terminals","flashlight",true,"Negative terminal has heavy corrosion between the terminal and post."),i("e2",.underHood,"Battery voltage","multimeter",false,"Battery rests at 12.62 V."),i("e3",.underHood,"Ground-side voltage drop","multimeter",true,"1.84 V is measured during the crank attempt — excessive resistance in the ground path.")],
                  causes:[c("c1","High-resistance negative battery connection",true),c("c2","Failed starter"),c("c3","Immobilizer fault"),c("c4","Alternator failure")],
                  repairs:[c("r1","Service the negative terminal/cable and verify cranking voltage drop",true),c("r2","Replace starter"),c("r3","Replace battery without testing"),c("r4","Program new keys")],
                  explanation:"A charged battery and an excessive ground-side voltage drop prove resistance in the return path.", rootCause:"High-resistance negative battery terminal", correctRepair:"Clean/repair the connection and retest under load", takeaways:["Static battery voltage does not prove the starting circuit is healthy.","Voltage-drop testing finds resistance under load."]),

            .init(id:"apprentice-misfire", difficulty:.apprentice, brand:"SMC",
                  repairOrder:.init(vehicle:"2019 SMC Zenith LT", mileage:84500, complaint:"Check-engine light and stumble at highway speed under light acceleration.", notes:"More noticeable on hills."),
                  tools:[t("scan_tool"),t("flashlight"),t("multimeter"),t("test_drive")],
                  inspections:[i("a1",.cockpit,"Misfire counters","scan_tool",true,"P0300 is stored; cylinder 1 misfire count climbs rapidly under load."),i("a2",.underHood,"Cylinder 1 plug","flashlight",true,"Plug shows carbon tracking and a worn electrode."),i("a3",.underHood,"Coil power/ground","multimeter",false,"Power and ground are within specification."),i("a4",.exterior,"Loaded road test","test_drive",true,"Swapping coil 1 to another cylinder moves the misfire with the coil.")],
                  causes:[c("c1","Failed cylinder 1 ignition coil",true),c("c2","Restricted catalyst"),c("c3","EVAP purge valve"),c("c4","Crank sensor")],
                  repairs:[c("r1","Replace coil 1 and damaged plug; verify counters",true),c("r2","Replace catalyst"),c("r3","Replace injectors"),c("r4","Adjust valves")],
                  explanation:"The misfire follows the coil during a controlled swap, directly proving the component failure.", rootCause:"Ignition coil failure", correctRepair:"Replace coil 1 and the carbon-tracked spark plug", takeaways:["A DTC is a direction, not a parts order.","A safe component swap can be an excellent proof test."]),

            .init(id:"technician-inverter", difficulty:.technician, brand:"Aeon Mobility",
                  repairOrder:.init(vehicle:"2021 Aeon Voltura Hybrid", mileage:78450, complaint:"Hybrid warning, front whine and power loss after highway driving.", notes:"Usually starts after about 20 minutes."),
                  tools:[t("scan_tool"),t("flashlight"),t("stethoscope"),t("test_drive")],
                  inspections:[i("t1",.cockpit,"Hybrid temperature data","scan_tool",true,"Inverter temperature rises rapidly as the fault appears."),i("t2",.underHood,"Inverter coolant","flashlight",true,"Reservoir is below MIN with residue near the cap."),i("t3",.underHood,"Cooling pump","stethoscope",true,"Grinding whine is isolated to the electric inverter coolant pump."),i("t4",.exterior,"Road test","test_drive",true,"Power is reduced exactly as inverter temperature spikes.")],
                  causes:[c("c1","Failed inverter cooling pump",true),c("c2","Traction motor failure"),c("c3","EVAP fault"),c("c4","Accessory belt")],
                  repairs:[c("r1","Replace pump, repair leak as needed, refill and bleed circuit",true),c("r2","Replace traction motor"),c("r3","Replace HV battery"),c("r4","Replace belt")],
                  explanation:"Temperature correlation plus the physically isolated pump noise points to loss of inverter cooling capacity.", rootCause:"Failed inverter cooling pump", correctRepair:"Replace pump and restore/bleed coolant circuit", takeaways:["Time and temperature are diagnostic variables.","Prove whether the warning code is cause or consequence."]),

            .init(id:"senior-can", difficulty:.senior, brand:"Kestrel Automotive",
                  repairOrder:.init(vehicle:"2020 Kestrel Vector AWD", mileage:63890, complaint:"Multiple warnings and briefly heavy steering after sharp bumps.", notes:"Intermittent; battery recently replaced."),
                  tools:[t("scan_tool"),t("multimeter"),t("flashlight"),t("test_drive")],
                  inspections:[i("s1",.cockpit,"Network scan","scan_tool",true,"Multiple modules store history U-codes for lost communication with power steering."),i("s2",.underHood,"CAN resistance","multimeter",false,"Network asleep resistance is approximately 60 ohms."),i("s3",.underHood,"Steering harness","flashlight",true,"Harness rubs a bracket and has a polished insulation witness mark."),i("s4",.underHood,"CAN while flexing harness","multimeter",true,"Moving the harness intermittently pulls CAN-H low and drops communication."),i("s5",.exterior,"Rough-road validation","test_drive",true,"After isolating the chafed branch, the event cannot be reproduced.")],
                  causes:[c("c1","Intermittent CAN-H short at chafed harness",true),c("c2","Failed steering module"),c("c3","Weak battery"),c("c4","Open terminator")],
                  repairs:[c("r1","Repair/reroute the chafed network wiring and validate",true),c("r2","Replace steering module"),c("r3","Replace battery/alternator"),c("r4","Add terminating resistor")],
                  explanation:"The static network looks normal, but harness stress reproduces the dropout and isolates the actual circuit fault.", rootCause:"Intermittent CAN-H short from harness chafing", correctRepair:"Repair/protect the network wiring and validate dynamically", takeaways:["Intermittent faults require dynamic testing.","History U-codes do not automatically condemn the named module."]),

            .init(id:"master-fuel", difficulty:.master, brand:"Nisshin Motors",
                  repairOrder:.init(vehicle:"2017 Nisshin Apex-S", mileage:98450, complaint:"Highway surge feels like CVT slip; no warning lights.", notes:"Most noticeable under moderate acceleration."),
                  tools:[t("scan_tool"),t("pressure_gauge"),t("test_drive")],
                  inspections:[i("m1",.cockpit,"CVT and fuel trims","scan_tool",true,"Commanded/actual CVT ratios agree while LTFT is +12%."),i("m2",.underHood,"Fuel pressure under load","pressure_gauge",true,"42 psi at idle falls to 28 psi under load; specification is 48–52 psi."),i("m3",.exterior,"Data-logged road test","test_drive",true,"Every surge coincides with fuel pressure dropping below 30 psi while CVT ratio stays stable.")],
                  causes:[c("c1","Fuel pump cannot maintain volume under load",true),c("c2","CVT speed sensor"),c("c3","Restricted catalyst"),c("c4","Timing chain")],
                  repairs:[c("r1","Replace pump/filter module and verify loaded pressure",true),c("r2","Replace CVT valve body"),c("r3","Replace catalyst"),c("r4","Replace timing chain")],
                  explanation:"Transmission data is normal; lean correction and pressure loss under the exact failure condition prove a fuel-delivery problem.", rootCause:"In-tank fuel-pump volume failure", correctRepair:"Replace pump/filter module and validate pressure under load", takeaways:["Do not let the customer's description choose the system.","Correlate live data streams under the failure condition."]),

            .init(id:"diagnostic-5v", difficulty:.diagnostic, brand:"Nisshin Motors",
                  repairOrder:.init(vehicle:"2022 Nisshin Trail-X 2.5T", mileage:54120, complaint:"Engine cuts out over sharp bumps; several sensor codes appear together.", notes:"Multiple sensors were previously replaced elsewhere."),
                  tools:[t("scan_tool"),t("multimeter"),t("flashlight"),t("test_drive")],
                  inspections:[i("d1",.cockpit,"DTC topology","scan_tool",true,"Low-voltage codes appear together for multiple sensors sharing the same 5 V reference."),i("d2",.underHood,"5 V reference stationary","multimeter",false,"Reference is stable at 5.01 V while parked."),i("d3",.underHood,"Pressure-sensor branch","flashlight",true,"Harness is tight against an A/C line with a polished rub-through spot."),i("d4",.underHood,"5 V while stressing branch","multimeter",true,"Moving the branch collapses reference to 0.4 V and the engine stumbles."),i("d5",.exterior,"Bump-road validation","test_drive",true,"With the branch isolated and secured, the original road segment no longer causes a dropout.")],
                  causes:[c("c1","Intermittent short on shared 5 V reference",true),c("c2","Failed PCM regulator"),c("c3","Three failed sensors"),c("c4","Crank sensor")],
                  repairs:[c("r1","Repair/reroute the chafed reference branch and stress-test",true),c("r2","Replace PCM"),c("r3","Replace all pressure sensors"),c("r4","Replace crank sensor")],
                  explanation:"The shared circuit is the common denominator. Dynamic harness stress reproduces the reference collapse even though static voltage is perfect.", rootCause:"Chafed shared 5 V reference shorting to ground", correctRepair:"Repair/reroute the damaged branch and validate dynamically", takeaways:["Unrelated sensor codes can share one power/reference fault.","A good static reading does not clear an intermittent circuit."])
        ]

        func q(_ id:String,_ area:String,_ question:String,_ correct:String,_ a:String,_ b:String,_ cText:String,_ d:String,_ explanation:String) -> ASEQuestion {
            .init(id:id, area:area, question:question, choices:[.init(id:"A",text:a),.init(id:"B",text:b),.init(id:"C",text:cText),.init(id:"D",text:d)], correctID:correct, explanation:explanation)
        }
        aseQuestions = [
            q("a1","A1","Compression rises significantly during a wet compression test. What is most likely?","C","Burnt valve","Head gasket","Worn/stuck piston rings","Injector fault","Oil temporarily improves ring-to-wall sealing."),
            q("a2","A2","A transmission works cold but loses a clutch-applied gear hot. Likely cause?","B","Hot fluid too thick","Worn apply seal leaks with thinner hot ATF","Starter relay","Alignment","Internal leakage can increase as ATF thins with heat."),
            q("a3","A3","Clicking during sharp turns on a FWD vehicle most strongly suggests?","A","Outer CV joint","Pinion bearing","Clutch disc","Shift fork","Outer CV joints operate at high angle during turns."),
            q("a4","A4","Excessive negative camber most commonly wears which tire area?","B","Outer shoulder","Inner shoulder","Center","Both shoulders","Negative camber increases load on the inner tread."),
            q("a5","A5","Brake pedal slowly sinks under steady pressure at a stop. Most likely?","B","Air only","Internal master-cylinder bypass","Tires","Thermostat","Internal seal bypass lets the pedal continue moving."),
            q("a6","A6","A key-off draw stabilizes at 450 mA after modules should sleep. Normal?","B","Yes","No — excessive draw","Only in winter","Only with a new alternator","450 mA is far above a typical sleep-current range."),
            q("a7","A7","Both heater hoses are hot but cabin heat is poor. Most likely?","B","No coolant flow","Blend-door/air-side fault","Low engine oil","Bad spark plug","Hot hoses indicate hot coolant reaches the heater core."),
            q("a8","A8","Short-term fuel trim is -15%. What does it mean?","B","PCM adds fuel","PCM subtracts fuel for a rich condition","Battery is low","Catalyst is restricted","Negative trim means commanded fuel is being reduced.")
        ]
    }
}
