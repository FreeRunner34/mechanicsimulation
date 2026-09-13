from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"Expected one match in {path}, found {count}: {old[:100]!r}")
    path.write_text(text.replace(old, new, 1))


def replace_between(path: Path, start: str, end: str, replacement: str) -> None:
    text = path.read_text()
    a = text.index(start)
    b = text.index(end, a)
    path.write_text(text[:a] + replacement + text[b:])


# -----------------------------------------------------------------------------
# Case rotation: Dealer Mode is now a first-class native selector.
# -----------------------------------------------------------------------------
models = ROOT / "MasterMechanic" / "Models.swift"
old_next = '''    func nextCase(difficulty: Difficulty, excluding excludedIDs: Set<String> = []) -> DiagnosticCase? {
        let pool = playableCases.filter { $0.difficulty == difficulty }
        guard !pool.isEmpty else { return nil }
        let fresh = pool.filter { !excludedIDs.contains($0.id) }
        return (fresh.isEmpty ? pool : fresh).randomElement()
    }
'''
new_next = '''    func nextCase(difficulty: Difficulty, dealerBrand: String? = nil, excluding excludedIDs: Set<String> = []) -> DiagnosticCase? {
        let levelCases = playableCases.filter { $0.difficulty == difficulty }
        guard !levelCases.isEmpty else { return nil }

        let pool: [DiagnosticCase]
        if let dealerBrand {
            let exact = levelCases.filter { $0.brand == dealerBrand }
            pool = exact.isEmpty ? levelCases.map { Self.trainingVariant($0, brand: dealerBrand) } : exact
        } else {
            pool = levelCases
        }

        let fresh = pool.filter { !excludedIDs.contains($0.id) }
        return (fresh.isEmpty ? pool : fresh).randomElement()
    }

    private static func trainingVariant(_ base: DiagnosticCase, brand: String) -> DiagnosticCase {
        let model: String
        switch brand {
        case "Nisshin Motors": model = "Nisshin Field-X"
        case "Stellar Motors Corp": model = "SMC Zenith"
        case "Bayern Werke": model = "Bayern Werke R4"
        case "Kestrel Automotive": model = "Kestrel Vector"
        case "Aeon Mobility": model = "Aeon Meridian"
        default: model = brand
        }

        let yearPrefix = String(base.repairOrder.vehicle.prefix(4))
        let year = yearPrefix.allSatisfy(\\.isNumber) ? yearPrefix : "2021"
        let slug = brand.lowercased().replacingOccurrences(of: " ", with: "-")
        let order = RepairOrder(
            vehicle: "\\(year) \\(model)",
            mileage: base.repairOrder.mileage,
            complaint: base.repairOrder.complaint,
            notes: base.repairOrder.notes + " Dealer Mode training variant."
        )

        return DiagnosticCase(
            id: "\\(base.id)-dealer-\\(slug)",
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
'''
replace_once(models, old_next, new_next)


# -----------------------------------------------------------------------------
# Progress/replay semantics: replays do not inflate XP/career stats.
# -----------------------------------------------------------------------------
appdata = ROOT / "MasterMechanic" / "AppData.swift"
replace_once(appdata, '    var totalComebacks: Int { history.filter(\\.replay).count }\n    var totalWastedTests: Int { history.reduce(0) { $0 + $1.wastedTests } }',
'''    var totalComebacks: Int { history.filter { !$0.replay && !$0.solved }.count }
    var totalWastedTests: Int { history.filter { !$0.replay }.reduce(0) { $0 + $1.wastedTests } }''')
replace_once(appdata, '            let rows = history.filter { $0.difficulty == difficulty }', '            let rows = history.filter { $0.difficulty == difficulty && !$0.replay }')
replace_once(appdata,
'''        var ids = Set<String>()
        let flawless = history.filter { $0.solved && $0.wastedTests == 0 && $0.score >= 90 }.count
        let highestAdvancedScore = history.filter { $0.difficulty == .master || $0.difficulty == .diagnostic }.map(\\.score).max() ?? 0
''',
'''        var ids = Set<String>()
        let careerHistory = history.filter { !$0.replay }
        let flawless = careerHistory.filter { $0.solved && $0.wastedTests == 0 && $0.score >= 90 }.count
        let highestAdvancedScore = careerHistory.filter { $0.difficulty == .master || $0.difficulty == .diagnostic }.map(\\.score).max() ?? 0
''')
replace_once(appdata, '        if history.contains(where: { $0.score == 0 }) { ids.insert("goose_egg") }\n        if history.contains(where: { $0.wastedTests >= 5 }) { ids.insert("parts_cannon") }',
                         '        if careerHistory.contains(where: { $0.score == 0 }) { ids.insert("goose_egg") }\n        if careerHistory.contains(where: { $0.wastedTests >= 5 }) { ids.insert("parts_cannon") }')
old_record = '''    @discardableResult
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
'''
new_record = '''    @discardableResult
    func record(case diagnosticCase: DiagnosticCase, score: Int, solved: Bool, tests: Int, wastedTests: Int, replay: Bool = false) -> Int {
        let xp = replay ? 0 : Int((Double(max(0, score)) * diagnosticCase.difficulty.multiplier * 5).rounded())

        if !replay {
            completedCases += 1
            correctCases += solved ? 1 : 0
            streak = solved ? streak + 1 : 0
            lastScore = score
            points += xp
        }

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
'''
replace_once(appdata, old_record, new_record)


# -----------------------------------------------------------------------------
# Native UI parity: Dealer Mode, Library, Stats/Achievements, replay, XP result.
# -----------------------------------------------------------------------------
views = ROOT / "MasterMechanic" / "Views.swift"

# Dashboard quick links.
replace_once(views,
'''                VStack(alignment:.leading,spacing:10) {
                    SectionHeader("CAREER",progress.rank.uppercased())
                    ProgressView(value:min(Double(progress.points % 1500)/1500,1)).tint(accent)
                    Text("Cases score the diagnosis, repair choice, and how efficiently you gather evidence.").font(.footnote).foregroundStyle(.secondary)
                }.card()
                if !purchases.isPro {''',
'''                VStack(alignment:.leading,spacing:10) {
                    SectionHeader("CAREER",progress.rank.uppercased())
                    ProgressView(value:min(Double(progress.points % 1500)/1500,1)).tint(accent)
                    Text("Cases score the diagnosis, repair choice, and how efficiently you gather evidence.").font(.footnote).foregroundStyle(.secondary)
                }.card()
                HStack(spacing:10) {
                    NavigationLink { LibraryView() } label: { QuickLinkCard(title:"RO Library", subtitle:"Replay & review", symbol:"books.vertical.fill") }
                    NavigationLink { StatsAchievementsView() } label: { QuickLinkCard(title:"Career Stats", subtitle:"History & badges", symbol:"chart.bar.fill") }
                }.buttonStyle(.plain)
                if !purchases.isPro {''')

# Simulator state.
replace_once(views,
'''    @State private var selectedCase: DiagnosticCase?
    @State private var pendingNextDifficulty: Difficulty?
    @State private var lastLaunchedCaseID: String?
    private let data = AppData.shared
''',
'''    @State private var selectedCase: DiagnosticCase?
    @State private var pendingNextDifficulty: Difficulty?
    @State private var lastLaunchedCaseID: String?
    @State private var selectedDealerBrand: String?
    private let data = AppData.shared
''')

# Dealer Mode UI before difficulty cards.
replace_once(views,
'''                Text("Pick a difficulty").font(.title.bold())
                Text("Entry Level and Apprentice are free. Pro unlocks the full diagnostic ladder.").foregroundStyle(.secondary).padding(.bottom,4)
                ForEach(Difficulty.allCases) { level in
                    let available = data.playableCases.filter { $0.difficulty == level }
                    let locked = level.isPro && !purchases.isPro
''',
'''                Text("Pick a difficulty").font(.title.bold())
                Text("Entry Level and Apprentice are free. Pro unlocks the full diagnostic ladder.").foregroundStyle(.secondary).padding(.bottom,4)

                VStack(alignment:.leading,spacing:10) {
                    SectionHeader("DEALER MODE", selectedDealerBrand == nil ? "MIXED BRAND" : "LOCKED TO BRAND")
                    ScrollView(.horizontal,showsIndicators:false) {
                        HStack(spacing:8) {
                            Button { selectedDealerBrand = nil } label: { DealerChip(title:"Mixed", selected:selectedDealerBrand == nil) }.buttonStyle(.plain)
                            ForEach(data.brands) { brand in
                                Button { selectedDealerBrand = brand.id } label: { DealerChip(title:brand.shortName, selected:selectedDealerBrand == brand.id) }.buttonStyle(.plain)
                            }
                        }
                    }
                    Text(selectedDealerBrand == nil ? "Rotate through every fictional manufacturer." : "Repair orders stay with this manufacturer; a training variant is created if a tier has no exact-brand case.")
                        .font(.caption).foregroundStyle(.secondary)
                }.card()

                ForEach(Difficulty.allCases) { level in
                    let levelCases = data.playableCases.filter { $0.difficulty == level }
                    let exactBrandCases = selectedDealerBrand.map { brand in levelCases.filter { $0.brand == brand } } ?? levelCases
                    let displayedCount = exactBrandCases.isEmpty ? levelCases.count : exactBrandCases.count
                    let locked = level.isPro && !purchases.isPro
''')
replace_once(views,
'''                                if !available.isEmpty {
                                    Text("\\(available.count) repair orders in rotation").font(.caption2).foregroundStyle(accent.opacity(0.8))
                                }
''',
'''                                if !levelCases.isEmpty {
                                    Text("\\(displayedCount) repair orders in rotation").font(.caption2).foregroundStyle(accent.opacity(0.8))
                                }
''')
replace_once(views, '                    }.buttonStyle(.plain).disabled(available.isEmpty)', '                    }.buttonStyle(.plain).disabled(levelCases.isEmpty)')
replace_once(views,
'        let next = data.nextCase(difficulty: level, excluding: excluded) ?? pool.randomElement()',
'        let next = data.nextCase(difficulty: level, dealerBrand: selectedDealerBrand, excluding: excluded) ?? pool.randomElement()')

# Replays and earned XP.
replace_once(views,
'''    let diagnosticCase: DiagnosticCase
    let onNext: () -> Void
    @State private var bay: BayView = .underHood
''',
'''    let diagnosticCase: DiagnosticCase
    var isReplay: Bool = false
    let onNext: () -> Void
    @State private var bay: BayView = .underHood
''')
replace_once(views,
'''        _ = progress.record(
            case: diagnosticCase,
            score: score,
            solved: cause && repair,
            tests: revealed.count,
            wastedTests: wasted
        )
        result = .init(score: score, solved: cause && repair, correctCause: cause, correctRepair: repair, tests: revealed.count, wastedTests: wasted)
''',
'''        let xp = progress.record(
            case: diagnosticCase,
            score: score,
            solved: cause && repair,
            tests: revealed.count,
            wastedTests: wasted,
            replay: isReplay
        )
        result = .init(score: score, solved: cause && repair, correctCause: cause, correctRepair: repair, tests: revealed.count, wastedTests: wasted, xp: xp)
''')
replace_once(views,
'struct CaseResult:Identifiable{let id=UUID();let score:Int;let solved:Bool;let correctCause:Bool;let correctRepair:Bool;let tests:Int;let wastedTests:Int}',
'struct CaseResult:Identifiable{let id=UUID();let score:Int;let solved:Bool;let correctCause:Bool;let correctRepair:Bool;let tests:Int;let wastedTests:Int;let xp:Int}')
replace_once(views,
'''        Text(result.solved ? "COMEBACK AVOIDED":"CUSTOMER CAME BACK").font(.title2.weight(.black)).foregroundStyle(result.solved ? accent:.red)
        VStack(alignment:.leading,spacing:12){''',
'''        Text(result.solved ? "COMEBACK AVOIDED":"CUSTOMER CAME BACK").font(.title2.weight(.black)).foregroundStyle(result.solved ? accent:.red)
        Text(result.xp > 0 ? "+\\(result.xp) XP" : "Replay — no career XP").font(.headline).foregroundStyle(result.xp > 0 ? accent : Color.secondary)
        VStack(alignment:.leading,spacing:12){''')

# Quiz now gives immediate educational feedback before advancing.
new_quiz = r'''struct QuizView: View {
    @Environment(\.dismiss) private var dismiss
    let seed: QuizSeed
    @State private var index = 0
    @State private var selected: String?
    @State private var correct = 0
    @State private var finished = false
    @State private var answered = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if seed.questions.isEmpty {
                ContentUnavailableView("No questions loaded", systemImage: "questionmark.folder")
            } else if finished {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 70)).foregroundStyle(accent)
                    Text("\(correct) / \(seed.questions.count)").font(.system(size: 48, weight: .black))
                    Text(seed.title).foregroundStyle(.secondary)
                    Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                }.padding()
            } else {
                let question = seed.questions[index]
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(seed.area).foregroundStyle(accent).font(.headline.monospaced())
                            Spacer()
                            Text("\(index + 1) / \(seed.questions.count)").foregroundStyle(.secondary)
                        }
                        Text(question.question).font(.title3.bold()).padding(.vertical, 5)
                        ForEach(question.choices) { choice in
                            ChoiceRow(text: "\(choice.id). \(choice.text)", selected: selected == choice.id) {
                                if !answered { selected = choice.id }
                            }
                            .allowsHitTesting(!answered)
                        }

                        if answered {
                            let passed = selected?.lowercased() == question.correctID.lowercased()
                            let correctText = question.choices.first { $0.id.lowercased() == question.correctID.lowercased() }?.text ?? question.correctID
                            VStack(alignment:.leading,spacing:8) {
                                Label(passed ? "Correct" : "Not quite", systemImage: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.headline).foregroundStyle(passed ? accent : Color.red)
                                if !passed { Text("Correct answer: \(question.correctID). \(correctText)").font(.subheadline.bold()) }
                                Text(question.explanation).font(.subheadline).foregroundStyle(.white.opacity(0.78))
                            }.card()
                        }

                        Button(answered ? (index == seed.questions.count - 1 ? "Finish" : "Next question") : "Check answer") {
                            if !answered {
                                if selected?.lowercased() == question.correctID.lowercased() { correct += 1 }
                                answered = true
                            } else {
                                selected = nil
                                answered = false
                                if index == seed.questions.count - 1 { finished = true } else { index += 1 }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(selected == nil)
                        .opacity(selected == nil ? 0.45 : 1)
                    }.padding()
                }
            }
        }
        .navigationTitle(seed.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Exit") { dismiss() }.foregroundStyle(.secondary) } }
    }
}
'''
replace_between(views, 'struct QuizView: View {', '\nstruct ToolboxView:View', new_quiz)

# Profile career navigation.
replace_once(views,
'''    var body:some View{List{Section{VStack(alignment:.leading,spacing:6){Text(progress.rank).font(.title2.bold());Text("\\(progress.points) XP · \\(progress.completedCases) cases · \\(progress.accuracy)% accuracy").foregroundStyle(.secondary)}};Section("ACCESS"){''',
'''    var body:some View{List{Section{VStack(alignment:.leading,spacing:6){Text(progress.rank).font(.title2.bold());Text("\\(progress.points) XP · \\(progress.completedCases) cases · \\(progress.accuracy)% accuracy").foregroundStyle(.secondary)}};Section("CAREER"){NavigationLink("Repair Order Library"){LibraryView()};NavigationLink("Stats & Achievements"){StatsAchievementsView()}};Section("ACCESS"){''')

# Insert Library and Stats/Achievements before ToolboxView.
insert_views = r'''
struct LibraryView: View {
    @EnvironmentObject var progress: ProgressStore
    @State private var difficultyFilter: Difficulty?
    @State private var query = ""
    @State private var selectedCase: DiagnosticCase?
    @State private var pendingNextDifficulty: Difficulty?
    private let data = AppData.shared

    private var filteredCases: [DiagnosticCase] {
        data.playableCases.filter { item in
            let difficultyMatches = difficultyFilter == nil || item.difficulty == difficultyFilter
            let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchMatches = search.isEmpty || item.repairOrder.vehicle.localizedCaseInsensitiveContains(search) || item.repairOrder.complaint.localizedCaseInsensitiveContains(search) || (item.brand?.localizedCaseInsensitiveContains(search) ?? false)
            return difficultyMatches && searchMatches
        }
        .sorted { lhs, rhs in
            let li = Difficulty.allCases.firstIndex { $0.rawValue == lhs.difficulty.rawValue } ?? 0
            let ri = Difficulty.allCases.firstIndex { $0.rawValue == rhs.difficulty.rawValue } ?? 0
            return li == ri ? lhs.repairOrder.vehicle < rhs.repairOrder.vehicle : li < ri
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment:.leading,spacing:11) {
                Text("Repair Order Library").font(.title.bold())
                Text("Review the native case catalog and replay any RO. Replays record a best score but do not award career XP.").font(.subheadline).foregroundStyle(.secondary)
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:8) {
                        Button { difficultyFilter = nil } label: { FilterChip(title:"All", selected:difficultyFilter == nil) }.buttonStyle(.plain)
                        ForEach(Difficulty.allCases) { difficulty in
                            Button { difficultyFilter = difficulty } label: { FilterChip(title:difficulty.shortLabel, selected:difficultyFilter?.rawValue == difficulty.rawValue) }.buttonStyle(.plain)
                        }
                    }
                }
                Text("\(filteredCases.count) repair orders").font(.caption.bold()).foregroundStyle(accent).padding(.top,4)
                ForEach(filteredCases) { item in
                    Button { selectedCase = item } label: {
                        VStack(alignment:.leading,spacing:7) {
                            HStack {
                                Text(item.repairOrder.vehicle).font(.headline).foregroundStyle(.white)
                                Spacer()
                                Text(item.difficulty.shortLabel).font(.caption2.bold()).foregroundStyle(accent)
                            }
                            Text(item.repairOrder.complaint).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                            HStack(spacing:12) {
                                if let brand = item.brand { Label(brand,systemImage:"building.2.fill") }
                                let attempts = progress.attempts(for:item.id)
                                Label(attempts == 0 ? "New" : "\(attempts) attempts",systemImage:"arrow.counterclockwise")
                                if let best = progress.bestScore(for:item.id) { Label("Best \(best)",systemImage:"star.fill") }
                            }.font(.caption2).foregroundStyle(.secondary)
                        }.padding(14).background(panel).clipShape(RoundedRectangle(cornerRadius:16))
                    }.buttonStyle(.plain)
                }
            }.padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text:$query,prompt:"Vehicle, brand, or complaint")
        .fullScreenCover(item:$selectedCase,onDismiss:{
            guard let difficulty = pendingNextDifficulty else { return }
            pendingNextDifficulty = nil
            DispatchQueue.main.asyncAfter(deadline:.now()+0.15) {
                selectedCase = data.nextCase(difficulty:difficulty,excluding:Set(progress.history.prefix(4).map(\.caseID)))
            }
        }) { value in
            NavigationStack {
                CaseSessionView(diagnosticCase:value,isReplay:true,onNext:{
                    pendingNextDifficulty = value.difficulty
                    selectedCase = nil
                })
            }
        }
    }
}

struct StatsAchievementsView: View {
    @EnvironmentObject var progress: ProgressStore
    private let data = AppData.shared
    private let columns = [GridItem(.flexible()),GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                Text("Career Overview").font(.title.bold())
                HStack(spacing:8) {
                    StatTile(value:"\(progress.points)",label:"XP",symbol:"bolt.fill")
                    StatTile(value:"\(progress.completedCases)",label:"Closed ROs",symbol:"clipboard.fill")
                    StatTile(value:"\(progress.accuracy)%",label:"Accuracy",symbol:"scope")
                }
                HStack(spacing:8) {
                    StatTile(value:"\(progress.averageScore)",label:"Avg Score",symbol:"gauge.with.dots.needle.50percent")
                    StatTile(value:"\(progress.streak)",label:"Streak",symbol:"flame.fill")
                    StatTile(value:"\(progress.totalComebacks)",label:"Comebacks",symbol:"arrow.uturn.backward.circle.fill")
                }

                SectionHeader("BY DIFFICULTY","CAREER JOBS")
                if progress.difficultyStats.isEmpty {
                    Text("Close a repair order to start building your career stats.").foregroundStyle(.secondary).card()
                } else {
                    ForEach(progress.difficultyStats) { stats in
                        HStack {
                            VStack(alignment:.leading,spacing:3) {
                                Text(stats.difficulty.rawValue).font(.headline)
                                Text("\(stats.cases) jobs · \(stats.xp) XP").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(stats.averageScore)").font(.title3.bold().monospacedDigit()).foregroundStyle(accent)
                        }.padding(14).background(panel).clipShape(RoundedRectangle(cornerRadius:16))
                    }
                }

                SectionHeader("ACHIEVEMENTS","\(progress.earnedAchievementIDs.count) / \(data.achievements.count)")
                LazyVGrid(columns:columns,spacing:10) {
                    ForEach(data.achievements) { achievement in
                        let earned = progress.earnedAchievementIDs.contains(achievement.id)
                        VStack(alignment:.leading,spacing:7) {
                            Image(systemName:achievement.symbol).font(.title2).foregroundStyle(earned ? (achievement.negative ? Color.red : accent) : Color.secondary)
                            Text(achievement.name).font(.headline).foregroundStyle(earned ? .white : .secondary)
                            Text(achievement.detail).font(.caption).foregroundStyle(.secondary)
                            Spacer(minLength:0)
                            Text(earned ? "EARNED" : "LOCKED").font(.caption2.weight(.black)).foregroundStyle(earned ? (achievement.negative ? Color.red : accent) : Color.secondary)
                        }.frame(maxWidth:.infinity,minHeight:145,alignment:.topLeading).padding(13).background(panel).clipShape(RoundedRectangle(cornerRadius:16))
                    }
                }

                SectionHeader("RECENT REPAIR ORDERS","LAST 10")
                if progress.history.isEmpty {
                    Text("No repair-order history yet.").foregroundStyle(.secondary).card()
                } else {
                    ForEach(Array(progress.history.prefix(10))) { entry in
                        HStack(spacing:12) {
                            Circle().fill(entry.solved ? accent.opacity(0.18) : Color.red.opacity(0.16)).frame(width:42,height:42).overlay(Image(systemName:entry.solved ? "checkmark.wrench.fill":"arrow.uturn.backward").foregroundStyle(entry.solved ? accent : Color.red))
                            VStack(alignment:.leading,spacing:3) {
                                Text(entry.vehicle).font(.subheadline.bold())
                                Text("\(entry.difficulty.shortLabel) · \(entry.date.formatted(date:.abbreviated,time:.omitted))\(entry.replay ? " · REPLAY" : "")").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment:.trailing,spacing:2) {
                                Text("\(entry.score)").font(.headline.monospacedDigit())
                                Text(entry.xp > 0 ? "+\(entry.xp) XP" : "No XP").font(.caption2).foregroundStyle(entry.xp > 0 ? accent : Color.secondary)
                            }
                        }.padding(12).background(panel).clipShape(RoundedRectangle(cornerRadius:15))
                    }
                }
            }.padding()
        }.background(Color.black.ignoresSafeArea()).navigationTitle("Stats & Achievements").navigationBarTitleDisplayMode(.inline)
    }
}

'''
text = views.read_text()
marker = 'struct ToolboxView:View'
if marker not in text:
    raise RuntimeError('ToolboxView marker missing')
text = text.replace(marker, insert_views + marker, 1)
views.write_text(text)

# Add compact reusable UI components.
text = views.read_text()
component_marker = 'struct StatTile:View'
extra_components = r'''struct QuickLinkCard:View{let title:String;let subtitle:String;let symbol:String;var body:some View{VStack(alignment:.leading,spacing:7){Image(systemName:symbol).font(.title2).foregroundStyle(accent);Text(title).font(.headline).foregroundStyle(.white);Text(subtitle).font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).padding(14).background(panel).clipShape(RoundedRectangle(cornerRadius:16))}}
struct DealerChip:View{let title:String;let selected:Bool;var body:some View{Text(title).font(.caption.bold()).padding(.horizontal,13).padding(.vertical,9).foregroundStyle(selected ? .black:.white).background(selected ? accent:panel).clipShape(Capsule()).overlay(Capsule().stroke(selected ? Color.clear:outline))}}
struct FilterChip:View{let title:String;let selected:Bool;var body:some View{Text(title).font(.caption2.bold()).padding(.horizontal,12).padding(.vertical,8).foregroundStyle(selected ? .black:.white).background(selected ? accent:panel).clipShape(Capsule())}}
'''
if component_marker not in text:
    raise RuntimeError('StatTile marker missing')
views.write_text(text.replace(component_marker, extra_components + component_marker, 1))


# -----------------------------------------------------------------------------
# Expand tests for Dealer Mode and replay integrity.
# -----------------------------------------------------------------------------
tests = ROOT / "MasterMechanicTests" / "MasterMechanicTests.swift"
text = tests.read_text()
needle = '''    func testTrainingBankHasAtLeastFiveQuestionsPerArea() {
        for area in ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"] {
            XCTAssertGreaterThanOrEqual(AppData.shared.trainingQuestions.filter { $0.area == area }.count, 5, area)
        }
    }
'''
addition = needle + '''
    func testDealerModeAlwaysReturnsSelectedBrand() {
        for brand in AppData.shared.brands {
            for difficulty in Difficulty.allCases {
                let next = AppData.shared.nextCase(difficulty: difficulty, dealerBrand: brand.id)
                XCTAssertEqual(next?.brand, brand.id, "Dealer Mode failed for \\(brand.id) / \\(difficulty.rawValue)")
            }
        }
    }

    @MainActor
    func testReplayDoesNotInflateCareerProgress() {
        let progress = ProgressStore()
        progress.reset()
        guard let diagnosticCase = AppData.shared.playableCases.first else {
            XCTFail("No playable case")
            return
        }

        let xp = progress.record(case: diagnosticCase, score: 100, solved: true, tests: 2, wastedTests: 0, replay: true)
        XCTAssertEqual(xp, 0)
        XCTAssertEqual(progress.points, 0)
        XCTAssertEqual(progress.completedCases, 0)
        XCTAssertEqual(progress.correctCases, 0)
        XCTAssertEqual(progress.streak, 0)
        XCTAssertEqual(progress.history.first?.replay, true)
        progress.reset()
    }
'''
if text.count(needle) != 1:
    raise RuntimeError('Training test marker mismatch')
tests.write_text(text.replace(needle, addition, 1))

print('Native parity patch applied: Dealer Mode, Library, Stats/Achievements, replay integrity, quiz feedback')
