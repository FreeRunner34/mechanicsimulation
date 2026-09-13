import SwiftUI
import StoreKit
import UIKit

private let accent = Color.orange
private let panel = Color.white.opacity(0.07)
private let outline = Color.white.opacity(0.12)

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }.tabItem { Label("Garage", systemImage:"house.fill") }
            NavigationStack { SimulatorView() }.tabItem { Label("Simulator", systemImage:"wrench.and.screwdriver.fill") }
            NavigationStack { TrainingView() }.tabItem { Label("Training", systemImage:"graduationcap.fill") }
            NavigationStack { ToolboxView() }.tabItem { Label("Toolbox", systemImage:"shippingbox.fill") }
            NavigationStack { ProfileView() }.tabItem { Label("Profile", systemImage:"person.crop.circle.fill") }
        }.tint(accent)
    }
}

struct DashboardView: View {
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var purchases: PurchaseManager
    var body: some View {
        ScrollView {
            VStack(spacing:16) {
                HStack(alignment:.bottom) {
                    VStack(alignment:.leading,spacing:3) {
                        Text("SERVICE DEPARTMENT").font(.caption2.weight(.black)).tracking(2).foregroundStyle(accent)
                        Text("Diagnostic Bay").font(.largeTitle.bold())
                    }
                    Spacer(); Text(progress.rank.uppercased()).font(.caption2.bold()).foregroundStyle(accent)
                }
                HStack(spacing:8) {
                    StatTile(value:"\(progress.points)",label:"XP",symbol:"bolt.fill")
                    StatTile(value:"\(progress.accuracy)%",label:"Accuracy",symbol:"scope")
                    StatTile(value:"\(progress.streak)",label:"Streak",symbol:"flame.fill")
                }
                NavigationLink { SimulatorView() } label: {
                    ZStack(alignment:.bottomLeading) {
                        RadialGradient(colors:[accent.opacity(0.35),.black],center:.topTrailing,startRadius:0,endRadius:380)
                        Image(systemName:"car.rear.and.tire.marks").font(.system(size:96,weight:.thin)).foregroundStyle(.white.opacity(0.12)).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topTrailing).padding()
                        VStack(alignment:.leading,spacing:7) {
                            Text("OPEN BAY").font(.caption.weight(.black)).tracking(2).foregroundStyle(accent)
                            Text("Diagnose the next vehicle").font(.title2.bold()).foregroundStyle(.white)
                            Text("Read the RO. Pick tests. Prove the fault. Make the repair call.").font(.subheadline).foregroundStyle(.white.opacity(0.72))
                            Label("Start diagnostic case",systemImage:"arrow.right.circle.fill").font(.headline).foregroundStyle(.white).padding(.top,8)
                        }.padding(22)
                    }.frame(minHeight:230).clipShape(RoundedRectangle(cornerRadius:26))
                }.buttonStyle(.plain)
                VStack(alignment:.leading,spacing:10) {
                    SectionHeader("CAREER",progress.rank.uppercased())
                    ProgressView(value:min(Double(progress.points % 1500)/1500,1)).tint(accent)
                    Text("Cases score the diagnosis, repair choice, and how efficiently you gather evidence.").font(.footnote).foregroundStyle(.secondary)
                }.card()
                HStack(spacing:10) {
                    NavigationLink { LibraryView() } label: { QuickLinkCard(title:"RO Library", subtitle:"Replay & review", symbol:"books.vertical.fill") }
                    NavigationLink { StatsAchievementsView() } label: { QuickLinkCard(title:"Career Stats", subtitle:"History & badges", symbol:"chart.bar.fill") }
                }.buttonStyle(.plain)
                if !purchases.isPro {
                    NavigationLink { ProView() } label: {
                        HStack { Image(systemName:"crown.fill").foregroundStyle(accent); VStack(alignment:.leading) { Text("MasterMechanic Pro").font(.headline).foregroundStyle(.white); Text("Unlock advanced diagnostic levels").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName:"chevron.right") }
                            .padding(16).background(panel).clipShape(RoundedRectangle(cornerRadius:18))
                    }.buttonStyle(.plain)
                }
            }.padding()
        }.background(Color.black.ignoresSafeArea()).navigationTitle("MasterMechanic").navigationBarTitleDisplayMode(.inline)
    }
}

struct SimulatorView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @EnvironmentObject var progress: ProgressStore
    @State private var selectedCase: DiagnosticCase?
    @State private var pendingNextDifficulty: Difficulty?
    @State private var lastLaunchedCaseID: String?
    @State private var selectedDealerBrand: String?
    private let data = AppData.shared

    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:12) {
                Text("Pick a difficulty").font(.title.bold())
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
                    Button {
                        if !locked { beginCase(level) }
                    } label: {
                        HStack(spacing:14) {
                            Circle().fill(locked ? Color.white.opacity(0.07):accent.opacity(0.14)).frame(width:48,height:48).overlay(Image(systemName:locked ? "lock.fill":"wrench.adjustable.fill").foregroundStyle(locked ? Color.secondary:accent))
                            VStack(alignment:.leading,spacing:4) {
                                Text(level.rawValue).font(.headline).foregroundStyle(.white)
                                Text(description(level)).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                                if !levelCases.isEmpty {
                                    Text("\(displayedCount) repair orders in rotation").font(.caption2).foregroundStyle(accent.opacity(0.8))
                                }
                            }
                            Spacer(); Text(locked ? "PRO":"OPEN").font(.caption2.bold()).foregroundStyle(locked ? accent:Color.secondary)
                        }.padding(15).background(panel).clipShape(RoundedRectangle(cornerRadius:18))
                    }.buttonStyle(.plain).disabled(levelCases.isEmpty)
                }
                if !purchases.isPro { NavigationLink("Unlock advanced levels") { ProView() }.buttonStyle(PrimaryButtonStyle()).padding(.top,6) }
            }.padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Simulator")
        .fullScreenCover(item:$selectedCase, onDismiss: {
            guard let level = pendingNextDifficulty else { return }
            pendingNextDifficulty = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                beginCase(level)
            }
        }) { value in
            NavigationStack {
                CaseSessionView(diagnosticCase:value, onNext: {
                    pendingNextDifficulty = value.difficulty
                    lastLaunchedCaseID = value.id
                    selectedCase = nil
                })
            }
        }
    }

    private func beginCase(_ level: Difficulty) {
        let pool = data.playableCases.filter { $0.difficulty == level }
        guard !pool.isEmpty else { return }

        var excluded = Set<String>()
        if let lastLaunchedCaseID { excluded.insert(lastLaunchedCaseID) }

        let recentLimit = max(1, min(4, pool.count - 1))
        let recentIDs = progress.history
            .filter { $0.difficulty == level }
            .prefix(recentLimit)
            .map(\.caseID)
        excluded.formUnion(recentIDs)

        let next = data.nextCase(difficulty: level, dealerBrand: selectedDealerBrand, excluding: excluded) ?? pool.randomElement()
        selectedCase = next
        lastLaunchedCaseID = next?.id
    }

    private func description(_ d:Difficulty)->String { switch d { case .entry:"Single-system faults and obvious evidence."; case .apprentice:"Scan data and basic electrical proof."; case .technician:"Multi-symptom system diagnosis."; case .senior:"Intermittent network and circuit faults."; case .master:"Symptoms that imitate another system."; case .diagnostic:"Shared circuits and dynamic proof tests." } }
}

struct CaseSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var progress: ProgressStore
    let diagnosticCase: DiagnosticCase
    var isReplay: Bool = false
    let onNext: () -> Void
    @State private var bay: BayView = .underHood
    @State private var toolID:String?
    @State private var revealed:Set<String> = []
    @State private var causeID:String?
    @State private var repairID:String?
    @State private var showRO = true
    @State private var result:CaseResult?

    var body: some View {
        ScrollView {
            VStack(spacing:14) {
                VStack(alignment:.leading,spacing:7) {
                    HStack { Text(diagnosticCase.difficulty.shortLabel).font(.caption2.weight(.black)).tracking(1.5).foregroundStyle(accent); Spacer(); Label("\(revealed.count) tests",systemImage:"checklist").font(.caption).foregroundStyle(.secondary) }
                    Text(diagnosticCase.repairOrder.vehicle).font(.title2.bold())
                    Text(diagnosticCase.repairOrder.complaint).font(.subheadline).foregroundStyle(.secondary)
                }.card()
                SectionHeader("BAY VIEW",bay.rawValue.uppercased())
                HStack(spacing:7) { ForEach(BayView.allCases) { view in Button { bay=view } label: { VStack(spacing:5) { Image(systemName:view.symbol); Text(short(view)).font(.caption2.bold()) }.frame(maxWidth:.infinity).padding(.vertical,10).foregroundStyle(bay == view ? .black:.white).background(bay == view ? accent:panel).clipShape(RoundedRectangle(cornerRadius:12)) }.buttonStyle(.plain) } }
                SectionHeader("TOOL CART",selectedToolName)
                ScrollView(.horizontal,showsIndicators:false) { HStack { ForEach(diagnosticCase.tools) { tool in Button { toolID=tool.id } label: { Label(tool.name,systemImage:tool.symbol).font(.caption.bold()).padding(.horizontal,12).padding(.vertical,9).foregroundStyle(toolID == tool.id ? .black:.white).background(toolID == tool.id ? accent:panel).clipShape(Capsule()) }.buttonStyle(.plain) } } }
                SectionHeader("INSPECTION","CHOOSE TESTS, NOT PARTS")
                let visible = diagnosticCase.inspections.filter { $0.view == bay }
                if visible.isEmpty { Text("No available tests from this view.").foregroundStyle(.secondary).frame(maxWidth:.infinity).padding(35).background(panel).clipShape(RoundedRectangle(cornerRadius:16)) }
                ForEach(visible) { item in
                    Button { run(item) } label: {
                        VStack(alignment:.leading,spacing:8) {
                            HStack { Text(item.label).font(.headline).foregroundStyle(.white); Spacer(); if revealed.contains(item.id) { Image(systemName:item.productive ? "checkmark.seal.fill":"minus.circle.fill").foregroundStyle(item.productive ? accent:Color.secondary) } }
                            if revealed.contains(item.id) { Text(item.finding).font(.subheadline).foregroundStyle(.white.opacity(0.78)).multilineTextAlignment(.leading) }
                            else { Text(toolID == item.toolID ? "Run test":"Select \(toolName(item.toolID))").font(.caption).foregroundStyle(toolID == item.toolID ? accent:Color.secondary) }
                        }.padding(14).background(panel).clipShape(RoundedRectangle(cornerRadius:15))
                    }.buttonStyle(.plain)
                }
                SectionHeader("FINAL CALL","DIAGNOSIS + REPAIR")
                Text("Root cause").font(.caption.bold()).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading)
                ForEach(diagnosticCase.causes) { option in ChoiceRow(text:option.text,selected:causeID == option.id) { causeID=option.id } }
                Text("Repair").font(.caption.bold()).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading).padding(.top,3)
                ForEach(diagnosticCase.repairs) { option in ChoiceRow(text:option.text,selected:repairID == option.id) { repairID=option.id } }
                Button("Submit repair order") { submit() }.buttonStyle(PrimaryButtonStyle()).disabled(causeID == nil || repairID == nil).opacity(causeID == nil || repairID == nil ? 0.45:1)
            }.padding()
        }.background(Color.black.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.topBarLeading){Button("Exit"){dismiss()}.foregroundStyle(.secondary)}; ToolbarItem(placement:.topBarTrailing){Button{showRO=true}label:{Image(systemName:"doc.text.fill")}.tint(accent)} }
            .sheet(isPresented:$showRO){RepairOrderView(order:diagnosticCase.repairOrder)}
            .fullScreenCover(item:$result){ value in ResultView(result:value,diagnosticCase:diagnosticCase,next:onNext){dismiss()} }
    }
    private func run(_ item:Inspection){ guard toolID == item.toolID else{return}; _ = revealed.insert(item.id); UIImpactFeedbackGenerator(style:.light).impactOccurred() }
    private func submit() {
        let cause = diagnosticCase.causes.first { $0.id == causeID }?.correct == true
        let repair = diagnosticCase.repairs.first { $0.id == repairID }?.correct == true
        let productive = diagnosticCase.inspections.filter { revealed.contains($0.id) && $0.productive }.count
        let total = max(diagnosticCase.inspections.filter { $0.productive }.count, 1)
        let wasted = diagnosticCase.inspections.filter { revealed.contains($0.id) && $0.productive == false }.count
        let score = max(0, min(100, (cause ? 45 : 0) + (repair ? 35 : 0) + Int(20 * Double(productive) / Double(total)) - wasted * 2))
        let xp = progress.record(
            case: diagnosticCase,
            score: score,
            solved: cause && repair,
            tests: revealed.count,
            wastedTests: wasted,
            replay: isReplay
        )
        result = .init(score: score, solved: cause && repair, correctCause: cause, correctRepair: repair, tests: revealed.count, wastedTests: wasted, xp: xp)
    }
    private var selectedToolName:String { diagnosticCase.tools.first{$0.id==toolID}?.name.uppercased() ?? "SELECT A TOOL" }
    private func toolName(_ id:String)->String{diagnosticCase.tools.first{$0.id==id}?.name ?? id}
    private func short(_ v:BayView)->String{switch v{case .underHood:"HOOD";case .underCar:"LIFT";case .cockpit:"CAB";case .exterior:"ROAD"}}
}

struct CaseResult:Identifiable{let id=UUID();let score:Int;let solved:Bool;let correctCause:Bool;let correctRepair:Bool;let tests:Int;let wastedTests:Int;let xp:Int}
struct ResultView: View {
    let result:CaseResult
    let diagnosticCase:DiagnosticCase
    let next:()->Void
    let done:()->Void
    var body: some View { ZStack { Color.black.ignoresSafeArea(); ScrollView { VStack(spacing:18) {
        ZStack { Circle().stroke(outline,lineWidth:12); Circle().trim(from:0,to:Double(result.score)/100).stroke(accent,style:StrokeStyle(lineWidth:12,lineCap:.round)).rotationEffect(.degrees(-90)); Text("\(result.score)").font(.system(size:52,weight:.black,design:.rounded)) }.frame(width:170,height:170).padding(.top,22)
        Text(result.solved ? "COMEBACK AVOIDED":"CUSTOMER CAME BACK").font(.title2.weight(.black)).foregroundStyle(result.solved ? accent:.red)
        Text(result.xp > 0 ? "+\(result.xp) XP" : "Replay — no career XP").font(.headline).foregroundStyle(result.xp > 0 ? accent : Color.secondary)
        VStack(alignment:.leading,spacing:12){ResultLine(label:"Root cause",value:diagnosticCase.rootCause,pass:result.correctCause);ResultLine(label:"Repair",value:diagnosticCase.correctRepair,pass:result.correctRepair);ResultLine(label:"Tests",value:"\(result.tests) (\(result.wastedTests) non-productive)",pass:nil)}.card()
        VStack(alignment:.leading,spacing:9){SectionHeader("WHY","DIAGNOSTIC LOGIC");Text(diagnosticCase.explanation).foregroundStyle(.white.opacity(0.8));ForEach(diagnosticCase.takeaways,id:\.self){Label($0,systemImage:"checkmark.circle.fill").font(.subheadline).foregroundStyle(.secondary)}}.card()
        Button("Next repair order",action:next).buttonStyle(PrimaryButtonStyle())
        Button("Return to garage",action:done).font(.headline).foregroundStyle(.secondary).padding(.vertical,8)
    }.padding() } } }
}

struct RepairOrderView:View{
    @Environment(\.dismiss) private var dismiss; let order:RepairOrder
    var body:some View{NavigationStack{ScrollView{VStack(alignment:.leading,spacing:0){Text("REPAIR ORDER").font(.caption.weight(.black)).tracking(3).foregroundStyle(.black.opacity(0.5));Text(order.vehicle).font(.title.bold()).foregroundStyle(.black).padding(.top,7);Text("\(order.mileage.formatted()) miles").foregroundStyle(.black.opacity(0.6));ROField(title:"CUSTOMER STATES",text:order.complaint);ROField(title:"SERVICE WRITER NOTES",text:order.notes);Text("Verify the concern, gather evidence, identify the root cause, and choose the repair that fixes it.").font(.footnote).foregroundStyle(.black.opacity(0.55)).padding(.top,20)}.padding(25).background(Color(red:0.95,green:0.92,blue:0.82)).clipShape(RoundedRectangle(cornerRadius:22)).padding()}.background(Color.black).navigationTitle("Work Order").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarTrailing){Button("Start"){dismiss()}.fontWeight(.bold).tint(accent)}}}}
}

struct TrainingView:View{
    @State private var quiz:QuizSeed?; let areas=[("A1","Engine Repair"),("A2","Automatic Transmission"),("A3","Manual Drivetrain"),("A4","Steering & Suspension"),("A5","Brakes"),("A6","Electrical"),("A7","HVAC"),("A8","Engine Performance")]
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:11){Text("ASE-style practice").font(.title.bold());Text("20-question tests drawn randomly from a 60+ question bank in each category. Independent practice content; not affiliated with or endorsed by ASE.").font(.footnote).foregroundStyle(.secondary).padding(.bottom,5);ForEach(areas,id:\.0){area in Button{quiz = .init(area:area.0,title:area.1,questions:AppData.shared.practiceTest(area:area.0, questionCount:20))}label:{HStack{Text(area.0).font(.headline.monospaced()).foregroundStyle(accent).frame(width:38);Text(area.1).font(.headline).foregroundStyle(.white);Spacer();Image(systemName:"chevron.right").foregroundStyle(.secondary)}.padding(15).background(panel).clipShape(RoundedRectangle(cornerRadius:16))}.buttonStyle(.plain)}}.padding()}.background(Color.black.ignoresSafeArea()).navigationTitle("Training").fullScreenCover(item:$quiz){seed in NavigationStack{QuizView(seed:seed)}}}
}
struct QuizSeed:Identifiable{let id=UUID();let area:String;let title:String;let questions:[ASEQuestion]}
struct QuizView: View {
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

struct ToolboxView:View{var body:some View{List(AppData.shared.toolReferences){tool in VStack(alignment:.leading,spacing:7){Label(tool.name,systemImage:tool.symbol).font(.headline).foregroundStyle(.white);Text(tool.use).font(.subheadline).foregroundStyle(.secondary);Text("SHOP TIP  ·  \(tool.tip)").font(.caption).foregroundStyle(accent)}.padding(.vertical,7).listRowBackground(Color.white.opacity(0.05))}.scrollContentBackground(.hidden).background(Color.black).navigationTitle("Toolbox")}}

struct ProfileView:View{
    @EnvironmentObject var progress:ProgressStore; @EnvironmentObject var purchases:PurchaseManager; @State private var confirmReset=false
    var body:some View{List{Section{VStack(alignment:.leading,spacing:6){Text(progress.rank).font(.title2.bold());Text("\(progress.points) XP · \(progress.completedCases) cases · \(progress.accuracy)% accuracy").foregroundStyle(.secondary)}};Section("CAREER"){NavigationLink("Repair Order Library"){LibraryView()};NavigationLink("Stats & Achievements"){StatsAchievementsView()}};Section("ACCESS"){if purchases.isPro{Label("MasterMechanic Pro unlocked",systemImage:"crown.fill").foregroundStyle(accent)}else{NavigationLink("Unlock Pro permanently"){ProView()}};Button("Restore purchases"){Task{await purchases.restore()}}};Section("PRIVACY & SUPPORT"){NavigationLink("Privacy"){PrivacyView()};Link("Support",destination:AppConfig.supportURL);Text("No MasterMechanic account is required. Progress is stored on this device.").font(.footnote).foregroundStyle(.secondary)};Section("DATA"){Button("Reset local progress",role:.destructive){confirmReset=true}};Section{Text("Independent educational simulator. Always use vehicle-specific service information and safety procedures for real repairs.").font(.footnote).foregroundStyle(.secondary)}}.scrollContentBackground(.hidden).background(Color.black).navigationTitle("Profile").confirmationDialog("Reset all local progress?",isPresented:$confirmReset,titleVisibility:.visible){Button("Reset progress",role:.destructive){progress.reset()}}.alert("Store",isPresented:Binding(get:{purchases.message != nil},set:{if !$0{purchases.message=nil}})){Button("OK"){purchases.message=nil}}message:{Text(purchases.message ?? "")}}
}

struct ProView:View{
    @EnvironmentObject var purchases:PurchaseManager
    var body:some View{ScrollView{VStack(spacing:18){Image(systemName:"crown.fill").font(.system(size:62)).foregroundStyle(accent).padding(.top,20);Text("MasterMechanic Pro").font(.largeTitle.bold());Text("Unlock Technician through Diagnostic Specialist cases permanently.").foregroundStyle(.secondary).multilineTextAlignment(.center);VStack(alignment:.leading,spacing:10){Label("All six diagnostic levels",systemImage:"checkmark.circle.fill");Label("Intermittent, electrical and network faults",systemImage:"checkmark.circle.fill");Label("Future Pro case packs included with this unlock",systemImage:"checkmark.circle.fill")}.card();Group{if let product=purchases.product{Text("\(product.displayPrice) one-time").font(.title2.bold())}else if purchases.isLoadingProduct{ProgressView("Loading App Store price…")}else{Text("App Store price unavailable").font(.headline).foregroundStyle(.secondary)}};Text("One-time purchase billed through Apple. No recurring charge. Restore it on supported devices using the same Apple ID.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center);Button(purchases.isPro ? "Pro is unlocked":(purchases.product == nil ? "Pro unavailable":"Unlock Pro")){Task{await purchases.buyPro()}}.buttonStyle(PrimaryButtonStyle()).disabled(purchases.isPro || purchases.product == nil);Button("Restore purchases"){Task{await purchases.restore()}}.foregroundStyle(accent);HStack(spacing:18){NavigationLink("Privacy policy"){PrivacyView()};Link("Support",destination:AppConfig.supportURL);Link("Terms of Use",destination:AppConfig.termsURL)}.font(.footnote)}.padding()}.background(Color.black.ignoresSafeArea()).navigationTitle("Pro").navigationBarTitleDisplayMode(.inline)}
}

struct PrivacyView:View{var body:some View{ScrollView{VStack(alignment:.leading,spacing:15){Text("Privacy").font(.largeTitle.bold());Text("MasterMechanic does not require an app account. Simulator progress and settings are stored locally on the device. StoreKit supplies purchase entitlement status so the app can determine whether Pro is active.");Text("This native build does not use Base44, Stripe, third-party advertising SDKs, analytics SDKs, or cross-app tracking.");Text("MasterMechanic does not sell personal information. Local simulator progress can be removed from Profile by resetting local progress or by deleting the app.");Link("Open published privacy policy",destination:AppConfig.privacyURL).foregroundStyle(accent)}.foregroundStyle(.white.opacity(0.85)).padding()}.background(Color.black.ignoresSafeArea())}}

struct QuickLinkCard:View{let title:String;let subtitle:String;let symbol:String;var body:some View{VStack(alignment:.leading,spacing:7){Image(systemName:symbol).font(.title2).foregroundStyle(accent);Text(title).font(.headline).foregroundStyle(.white);Text(subtitle).font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).padding(14).background(panel).clipShape(RoundedRectangle(cornerRadius:16))}}
struct DealerChip:View{let title:String;let selected:Bool;var body:some View{Text(title).font(.caption.bold()).padding(.horizontal,13).padding(.vertical,9).foregroundStyle(selected ? .black:.white).background(selected ? accent:panel).clipShape(Capsule()).overlay(Capsule().stroke(selected ? Color.clear:outline))}}
struct FilterChip:View{let title:String;let selected:Bool;var body:some View{Text(title).font(.caption2.bold()).padding(.horizontal,12).padding(.vertical,8).foregroundStyle(selected ? .black:.white).background(selected ? accent:panel).clipShape(Capsule())}}
struct StatTile:View{let value:String;let label:String;let symbol:String;var body:some View{VStack(spacing:5){Image(systemName:symbol).foregroundStyle(accent);Text(value).font(.headline.monospacedDigit());Text(label).font(.caption2).foregroundStyle(.secondary)}.frame(maxWidth:.infinity).padding(.vertical,13).background(panel).clipShape(RoundedRectangle(cornerRadius:15))}}
struct SectionHeader:View{let title:String;let subtitle:String;init(_ title:String,_ subtitle:String){self.title=title;self.subtitle=subtitle};var body:some View{HStack{Text(title).font(.caption.weight(.black)).tracking(1.7);Spacer();Text(subtitle).font(.caption2.bold()).foregroundStyle(.secondary)}}}
struct ChoiceRow:View{let text:String;let selected:Bool;let action:()->Void;var body:some View{Button(action:action){HStack(spacing:11){Image(systemName:selected ? "largecircle.fill.circle":"circle").foregroundStyle(selected ? accent:Color.secondary);Text(text).foregroundStyle(.white).multilineTextAlignment(.leading);Spacer()}.padding(13).background(selected ? accent.opacity(0.09):panel).overlay(RoundedRectangle(cornerRadius:14).stroke(selected ? accent.opacity(0.65):outline)).clipShape(RoundedRectangle(cornerRadius:14))}.buttonStyle(.plain)}}
struct ResultLine:View{let label:String;let value:String;let pass:Bool?;var body:some View{HStack(alignment:.top){VStack(alignment:.leading,spacing:2){Text(label.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary);Text(value).font(.subheadline)};Spacer();if let pass{Image(systemName:pass ? "checkmark.circle.fill":"xmark.circle.fill").foregroundStyle(pass ? accent:.red)}}}}
struct ROField:View{let title:String;let text:String;var body:some View{VStack(alignment:.leading,spacing:6){Text(title).font(.caption.weight(.black)).tracking(1.3).foregroundStyle(.black.opacity(0.5));Text(text).foregroundStyle(.black)}.padding(.top,21)}}
struct PrimaryButtonStyle:ButtonStyle{func makeBody(configuration:Configuration)->some View{configuration.label.font(.headline).frame(maxWidth:.infinity).padding(.vertical,14).background(accent.opacity(configuration.isPressed ? 0.72:1)).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius:15))}}
private extension View{func card()->some View{padding(16).background(panel).clipShape(RoundedRectangle(cornerRadius:19)).overlay(RoundedRectangle(cornerRadius:19).stroke(outline))}}
