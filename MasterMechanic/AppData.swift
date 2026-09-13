import Foundation
import Combine

struct CaseHistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let caseID: String
    let vehicle: String
    let difficulty: Difficulty
    let brand: String?
    let score: Int
    let xp: Int
    let solved: Bool
    let tests: Int
    let wastedTests: Int
    let replay: Bool
    let date: Date
}

struct DifficultyStats: Identifiable {
    let difficulty: Difficulty
    let cases: Int
    let averageScore: Int
    let xp: Int
    var id: String { difficulty.id }
}

struct FictionalBrand: Identifiable, Hashable {
    let id: String
    let shortName: String
}

struct AchievementDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
    let negative: Bool
}

@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var points: Int
    @Published private(set) var completedCases: Int
    @Published private(set) var correctCases: Int
    @Published private(set) var streak: Int
    @Published private(set) var lastScore: Int
    @Published private(set) var history: [CaseHistoryEntry]

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        points = defaults.integer(forKey: "progress.points")
        completedCases = defaults.integer(forKey: "progress.completed")
        correctCases = defaults.integer(forKey: "progress.correct")
        streak = defaults.integer(forKey: "progress.streak")
        lastScore = defaults.integer(forKey: "progress.lastScore")
        if let data = defaults.data(forKey: "progress.history"), let decoded = try? decoder.decode([CaseHistoryEntry].self, from: data) {
            history = decoded
        } else {
            history = []
        }
    }

    var accuracy: Int {
        completedCases == 0 ? 0 : Int((Double(correctCases) / Double(completedCases) * 100).rounded())
    }

    var averageScore: Int {
        history.isEmpty ? lastScore : Int((Double(history.reduce(0) { $0 + $1.score }) / Double(history.count)).rounded())
    }

    var totalComebacks: Int { history.filter(\.replay).count }
    var totalWastedTests: Int { history.reduce(0) { $0 + $1.wastedTests } }

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

    var difficultyStats: [DifficultyStats] {
        Difficulty.allCases.compactMap { difficulty in
            let rows = history.filter { $0.difficulty == difficulty }
            guard !rows.isEmpty else { return nil }
            return DifficultyStats(
                difficulty: difficulty,
                cases: rows.count,
                averageScore: Int((Double(rows.reduce(0) { $0 + $1.score }) / Double(rows.count)).rounded()),
                xp: rows.reduce(0) { $0 + $1.xp }
            )
        }
    }

    var earnedAchievementIDs: Set<String> {
        var ids = Set<String>()
        let flawless = history.filter { $0.solved && $0.wastedTests == 0 && $0.score >= 90 }.count
        let highestAdvancedScore = history.filter { $0.difficulty == .master || $0.difficulty == .diagnostic }.map(\.score).max() ?? 0

        if completedCases >= 1 { ids.insert("first_ro") }
        if flawless >= 1 { ids.insert("flawless") }
        if flawless >= 5 { ids.insert("flawless5") }
        if streak >= 5 { ids.insert("streak5") }
        if streak >= 8 { ids.insert("streak8") }
        if points >= 7000 { ids.insert("master") }
        if points >= 10000 { ids.insert("century") }
        if highestAdvancedScore >= 95 { ids.insert("big_ticket") }
        if history.contains(where: { $0.score == 0 }) { ids.insert("goose_egg") }
        if history.contains(where: { $0.wastedTests >= 5 }) { ids.insert("parts_cannon") }
        if totalWastedTests >= 50 { ids.insert("grease_monkey") }
        if completedCases >= 5 && accuracy < 20 { ids.insert("wrong_way") }

        let comebackIDs: [Difficulty: String] = [
            .entry: "comeback_entry",
            .apprentice: "comeback_apprentice",
            .technician: "comeback_technician",
            .senior: "comeback_senior",
            .master: "comeback_master",
            .diagnostic: "comeback_specialist"
        ]
        for stats in difficultyStats where stats.cases >= 2 && stats.averageScore < 20 {
            if let id = comebackIDs[stats.difficulty] { ids.insert(id) }
        }
        return ids
    }

    @discardableResult
    func record(case diagnosticCase: DiagnosticCase, score: Int, solved: Bool, tests: Int, wastedTests: Int, replay: Bool = false) -> Int {
        let xp = Int((Double(max(0, score)) * diagnosticCase.difficulty.multiplier * 5).rounded())
        completedCases += 1
        correctCases += solved ? 1 : 0
        streak = solved ? streak + 1 : 0
        lastScore = score
        points += xp
        history.insert(
            CaseHistoryEntry(
                id: UUID(),
                caseID: diagnosticCase.id,
                vehicle: diagnosticCase.repairOrder.vehicle,
                difficulty: diagnosticCase.difficulty,
                brand: diagnosticCase.brand,
                score: score,
                xp: xp,
                solved: solved,
                tests: tests,
                wastedTests: wastedTests,
                replay: replay,
                date: Date()
            ),
            at: 0
        )
        history = Array(history.prefix(250))
        persist()
        return xp
    }

    func bestScore(for caseID: String) -> Int? {
        history.filter { $0.caseID == caseID }.map(\.score).max()
    }

    func attempts(for caseID: String) -> Int {
        history.filter { $0.caseID == caseID }.count
    }

    func reset() {
        points = 0
        completedCases = 0
        correctCases = 0
        streak = 0
        lastScore = 0
        history = []
        persist()
    }

    private func persist() {
        defaults.set(points, forKey: "progress.points")
        defaults.set(completedCases, forKey: "progress.completed")
        defaults.set(correctCases, forKey: "progress.correct")
        defaults.set(streak, forKey: "progress.streak")
        defaults.set(lastScore, forKey: "progress.lastScore")
        if let data = try? encoder.encode(history) { defaults.set(data, forKey: "progress.history") }
    }
}

extension Difficulty {
    var multiplier: Double {
        switch self {
        case .entry: 1
        case .apprentice: 1.5
        case .technician: 2
        case .senior: 2.5
        case .master: 3.5
        case .diagnostic: 5
        }
    }
}

struct AppData {
    static let shared = AppData()

    let brands: [FictionalBrand] = [
        .init(id: "Nisshin Motors", shortName: "Nisshin"),
        .init(id: "Stellar Motors Corp", shortName: "SMC"),
        .init(id: "Bayern Werke", shortName: "Bayern"),
        .init(id: "Kestrel Automotive", shortName: "Kestrel"),
        .init(id: "Aeon Mobility", shortName: "Aeon")
    ]

    let achievements: [AchievementDefinition] = [
        .init(id:"first_ro", name:"First Ticket", detail:"Close your first repair order.", symbol:"clipboard.fill", negative:false),
        .init(id:"flawless", name:"Spotless", detail:"Solve a case with no wasted tests.", symbol:"sparkles", negative:false),
        .init(id:"flawless5", name:"Consistent", detail:"Five nearly flawless diagnoses.", symbol:"medal.fill", negative:false),
        .init(id:"streak5", name:"Streak King", detail:"Solve five repair orders in a row.", symbol:"flame.fill", negative:false),
        .init(id:"streak8", name:"In The Zone", detail:"Solve eight repair orders in a row.", symbol:"bolt.fill", negative:false),
        .init(id:"master", name:"Master Calling", detail:"Reach Master Technician rank.", symbol:"crown.fill", negative:false),
        .init(id:"century", name:"Century Club", detail:"Earn 10,000 total XP.", symbol:"trophy.fill", negative:false),
        .init(id:"big_ticket", name:"Big Ticket", detail:"Score 95+ on a Master or Diagnostic case.", symbol:"star.fill", negative:false),
        .init(id:"goose_egg", name:"Goose Egg", detail:"Score zero on a repair order. Bold strategy.", symbol:"xmark.seal.fill", negative:true),
        .init(id:"parts_cannon", name:"Parts Cannon", detail:"Make five or more wasted test moves in one case.", symbol:"hammer.fill", negative:true),
        .init(id:"grease_monkey", name:"Grease Monkey", detail:"Rack up 50 wasted tests across your career.", symbol:"drop.fill", negative:true),
        .init(id:"wrong_way", name:"Wrong Way", detail:"Stay below 20% case accuracy after five jobs.", symbol:"wrongwaysign.fill", negative:true),
        .init(id:"comeback_entry", name:"Comeback King — Entry", detail:"Average under 20 on Entry after multiple jobs.", symbol:"arrow.up.right.circle.fill", negative:true),
        .init(id:"comeback_apprentice", name:"Comeback King — Apprentice", detail:"Average under 20 on Apprentice after multiple jobs.", symbol:"arrow.up.right.circle.fill", negative:true),
        .init(id:"comeback_technician", name:"Comeback King — Technician", detail:"Average under 20 on Technician after multiple jobs.", symbol:"arrow.up.right.circle.fill", negative:true),
        .init(id:"comeback_senior", name:"Comeback King — Senior", detail:"Average under 20 on Senior after multiple jobs.", symbol:"arrow.up.right.circle.fill", negative:true),
        .init(id:"comeback_master", name:"Comeback King — Master", detail:"Average under 20 on Master after multiple jobs.", symbol:"arrow.up.right.circle.fill", negative:true),
        .init(id:"comeback_specialist", name:"Comeback King — Diagnostic", detail:"Average under 20 on Diagnostic after multiple jobs.", symbol:"arrow.up.right.circle.fill", negative:true)
    ]

    let tools: [DiagnosticTool] = [
        .init(id:"flashlight", name:"Inspection Light", symbol:"flashlight.on.fill", hint:"Visual inspection of leaks, wiring, wear and damage."),
        .init(id:"scan_tool", name:"Scan Tool", symbol:"waveform.path.ecg.rectangle", hint:"Read DTCs, freeze-frame and live data."),
        .init(id:"multimeter", name:"Digital Multimeter", symbol:"gauge.with.dots.needle.33percent", hint:"Check voltage, resistance and voltage drop."),
        .init(id:"pressure_gauge", name:"Pressure Gauge", symbol:"gauge.open.with.lines.needle.33percent", hint:"Measure fuel, compression and hydraulic pressure."),
        .init(id:"stethoscope", name:"Stethoscope", symbol:"ear.fill", hint:"Pinpoint mechanical noises and injector activity."),
        .init(id:"smoke_machine", name:"Smoke Machine", symbol:"aqi.medium", hint:"Locate intake and EVAP leaks."),
        .init(id:"test_drive", name:"Road Test", symbol:"road.lanes", hint:"Reproduce the concern under load.")
    ]

    var toolReferences: [ToolReference] {
        tools.map { .init(id:$0.id, name:$0.name, symbol:$0.symbol, use:$0.hint, tip:"Use the least invasive test that can prove or eliminate a theory.") }
    }

    var cases: [DiagnosticCase] = []
    var aseQuestions: [ASEQuestion] = []

    init() {
        func t(_ id:String) -> DiagnosticTool { tools.first { $0.id == id }! }
        func i(_ id:String,_ view:BayView,_ label:String,_ tool:String,_ productive:Bool,_ finding:String) -> Inspection { .init(id:id, view:view, label:label, toolID:tool, productive:productive, finding:finding) }
        func c(_ id:String,_ text:String,_ correct:Bool=false) -> DiagnosisChoice { .init(id:id, text:text, correct:correct) }

        cases = [
            .init(id:"entry-battery", difficulty:.entry, brand:"Kestrel Automotive",
                  repairOrder:.init(vehicle:"2018 Kestrel Vector 2.0", mileage:71220, complaint:"Single click when starting in the morning; lights look normal.", notes:"Jump-started once last week."),
                  tools:[t("flashlight"),t("multimeter")],
                  inspections:[i("e1",.underHood,"Battery terminals","flashlight",true,"Negative terminal has heavy corrosion between the terminal and post."),i("e2",.underHood,"Battery voltage","multimeter",false,"Battery rests at 12.62 V."),i("e3",.underHood,"Ground-side voltage drop","multimeter",true,"1.84 V is measured during the crank attempt — excessive resistance in the ground path.")],
                  causes:[c("c1","High-resistance negative battery connection",true),c("c2","Failed starter"),c("c3","Immobilizer fault"),c("c4","Alternator failure")],
                  repairs:[c("r1","Service the negative terminal/cable and verify cranking voltage drop",true),c("r2","Replace starter"),c("r3","Replace battery without testing"),c("r4","Program new keys")],
                  explanation:"A charged battery and an excessive ground-side voltage drop prove resistance in the return path.", rootCause:"High-resistance negative battery terminal", correctRepair:"Clean/repair the connection and retest under load", takeaways:["Static battery voltage does not prove the starting circuit is healthy.","Voltage-drop testing finds resistance under load."]),

            .init(id:"apprentice-misfire", difficulty:.apprentice, brand:"Stellar Motors Corp",
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

            .init(id:"technician-bayern-brake", difficulty:.technician, brand:"Bayern Werke",
                  repairOrder:.init(vehicle:"2020 Bayern Werke R3 Touring", mileage:66940, complaint:"ABS activates at very low speed just before stopping on dry pavement.", notes:"No warning lamps; front wheel bearing replaced recently."),
                  tools:[t("scan_tool"),t("flashlight"),t("multimeter"),t("test_drive")],
                  inspections:[i("b1",.cockpit,"Wheel-speed graph","scan_tool",true,"Right-front wheel speed drops to 0 mph intermittently while the other three still show 4–5 mph."),i("b2",.underCar,"Right-front sensor/tone surface","flashlight",true,"Sensor is seated, but metallic debris is visible at the magnetic encoder surface."),i("b3",.underCar,"Sensor circuit","multimeter",false,"Power, ground and signal wiring pass static checks."),i("b4",.exterior,"Low-speed validation","test_drive",true,"Cleaning the encoder area restores a stable right-front signal and false ABS activation disappears.")],
                  causes:[c("c1","Contaminated right-front magnetic encoder signal",true),c("c2","ABS hydraulic unit"),c("c3","Brake booster"),c("c4","Rear wheel-speed sensor")],
                  repairs:[c("r1","Correct encoder contamination/damage and verify wheel-speed data",true),c("r2","Replace ABS module"),c("r3","Replace brake booster"),c("r4","Flush brake fluid")],
                  explanation:"The event lines up with one wheel-speed input dropping out at walking speed. Static wiring checks are normal, and correcting the encoder signal removes the concern.", rootCause:"Right-front wheel-speed encoder signal dropout", correctRepair:"Correct the encoder surface/sensor interface and verify live wheel-speed data", takeaways:["Graph all related wheel speeds together.","Recent work near the fault area deserves inspection, not assumptions."]),

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

    func caseFor(difficulty: Difficulty, dealerBrand: String?) -> DiagnosticCase? {
        let levelCases = cases.filter { $0.difficulty == difficulty }
        guard let base = levelCases.randomElement() else { return nil }
        guard let dealerBrand else { return base }
        if let exact = levelCases.filter({ $0.brand == dealerBrand }).randomElement() { return exact }
        return dealerVariant(base, brand: dealerBrand)
    }

    private func dealerVariant(_ base: DiagnosticCase, brand: String) -> DiagnosticCase {
        let model: String
        switch brand {
        case "Nisshin Motors": model = "Nisshin Field-X"
        case "Stellar Motors Corp": model = "SMC Zenith"
        case "Bayern Werke": model = "Bayern Werke R4"
        case "Kestrel Automotive": model = "Kestrel Vector"
        case "Aeon Mobility": model = "Aeon Meridian"
        default: model = brand
        }
        let order = RepairOrder(
            vehicle: "\(year(from: base.repairOrder.vehicle)) \(model)",
            mileage: base.repairOrder.mileage,
            complaint: base.repairOrder.complaint,
            notes: base.repairOrder.notes + " Dealer Mode training variant."
        )
        let slug = brand.lowercased().replacingOccurrences(of: " ", with: "-")
        return DiagnosticCase(
            id: "\(base.id)-dealer-\(slug)",
            difficulty: base.difficulty,
            brand: brand,
            repairOrder: order,
            tools: base.tools,
            inspections: base.inspections,
            causes: base.causes,
            repairs: base.repairs,
            explanation: base.explanation,
            rootCause: base.rootCause,
            correctRepair: base.correctRepair,
            takeaways: base.takeaways
        )
    }

    private func year(from vehicle: String) -> String {
        String(vehicle.prefix(4)).allSatisfy(\.isNumber) ? String(vehicle.prefix(4)) : "2021"
    }
}
