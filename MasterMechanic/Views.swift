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
    @State private var selectedCase: DiagnosticCase?
    private let data = AppData.shared
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:12) {
                Text("Pick a difficulty").font(.title.bold())
                Text("Entry Level and Apprentice are free. Pro unlocks the full diagnostic ladder.").foregroundStyle(.secondary).padding(.bottom,4)
                ForEach(Difficulty.allCases) { level in
                    let cases = data.cases.filter { $0.difficulty == level }
                    let locked = level.isPro && !purchases.isPro
                    Button {
                        if !locked { selectedCase = cases.randomElement() }
                    } label: {
                        HStack(spacing:14) {
                            Circle().fill(locked ? Color.white.opacity(0.07):accent.opacity(0.14)).frame(width:48,height:48).overlay(Image(systemName:locked ? "lock.fill":"wrench.adjustable.fill").foregroundStyle(locked ? Color.secondary:accent))
                            VStack(alignment:.leading,spacing:4) { Text(level.rawValue).font(.headline).foregroundStyle(.white); Text(description(level)).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
                            Spacer(); Text(locked ? "PRO":"OPEN").font(.caption2.bold()).foregroundStyle(locked ? accent:Color.secondary)
                        }.padding(15).background(panel).clipShape(RoundedRectangle(cornerRadius:18))
                    }.buttonStyle(.plain).disabled(cases.isEmpty)
                }
                if !purchases.isPro { NavigationLink("Unlock advanced levels") { ProView() }.buttonStyle(PrimaryButtonStyle()).padding(.top,6) }
            }.padding()
        }.background(Color.black.ignoresSafeArea()).navigationTitle("Simulator")
            .fullScreenCover(item:$selectedCase) { value in NavigationStack { CaseSessionView(diagnosticCase:value) } }
    }
    private func description(_ d:Difficulty)->String { switch d { case .entry:"Single-system faults and obvious evidence."; case .apprentice:"Scan data and basic electrical proof."; case .technician:"Multi-symptom system diagnosis."; case .senior:"Intermittent network and circuit faults."; case .master:"Symptoms that imitate another system."; case .diagnostic:"Shared circuits and dynamic proof tests." } }
}

struct CaseSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var progress: ProgressStore
    let diagnosticCase: DiagnosticCase
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
            .fullScreenCover(item:$result){ value in ResultView(result:value,diagnosticCase:diagnosticCase){dismiss()} }
    }
    private func run(_ item:Inspection){ guard toolID == item.toolID else{return}; _ = revealed.insert(item.id); UIImpactFeedbackGenerator(style:.light).impactOccurred() }
    private func submit() {
        let cause = diagnosticCase.causes.first { $0.id == causeID }?.correct == true
        let repair = diagnosticCase.repairs.first { $0.id == repairID }?.correct == true
        let productive = diagnosticCase.inspections.filter { revealed.contains($0.id) && $0.productive }.count
        let total = max(diagnosticCase.inspections.filter { $0.productive }.count, 1)
        let wasted = diagnosticCase.inspections.filter { revealed.contains($0.id) && $0.productive == false }.count
        let score = max(0, min(100, (cause ? 45 : 0) + (repair ? 35 : 0) + Int(20 * Double(productive) / Double(total)) - wasted * 2))
        progress.record(score: score, solved: cause && repair)
        result = .init(score: score, solved: cause && repair, correctCause: cause, correctRepair: repair, tests: revealed.count, wastedTests: wasted)
    }
    private var selectedToolName:String { diagnosticCase.tools.first{$0.id==toolID}?.name.uppercased() ?? "SELECT A TOOL" }
    private func toolName(_ id:String)->String{diagnosticCase.tools.first{$0.id==id}?.name ?? id}
    private func short(_ v:BayView)->String{switch v{case .underHood:"HOOD";case .underCar:"LIFT";case .cockpit:"CAB";case .exterior:"ROAD"}}
}

struct CaseResult:Identifiable{let id=UUID();let score:Int;let solved:Bool;let correctCause:Bool;let correctRepair:Bool;let tests:Int;let wastedTests:Int}
struct ResultView: View {
    let result:CaseResult; let diagnosticCase:DiagnosticCase; let done:()->Void
    var body: some View { ZStack { Color.black.ignoresSafeArea(); ScrollView { VStack(spacing:18) {
        ZStack { Circle().stroke(outline,lineWidth:12); Circle().trim(from:0,to:Double(result.score)/100).stroke(accent,style:StrokeStyle(lineWidth:12,lineCap:.round)).rotationEffect(.degrees(-90)); Text("\(result.score)").font(.system(size:52,weight:.black,design:.rounded)) }.frame(width:170,height:170).padding(.top,22)
        Text(result.solved ? "COMEBACK AVOIDED":"CUSTOMER CAME BACK").font(.title2.weight(.black)).foregroundStyle(result.solved ? accent:.red)
        VStack(alignment:.leading,spacing:12){ResultLine(label:"Root cause",value:diagnosticCase.rootCause,pass:result.correctCause);ResultLine(label:"Repair",value:diagnosticCase.correctRepair,pass:result.correctRepair);ResultLine(label:"Tests",value:"\(result.tests) (\(result.wastedTests) non-productive)",pass:nil)}.card()
        VStack(alignment:.leading,spacing:9){SectionHeader("WHY","DIAGNOSTIC LOGIC");Text(diagnosticCase.explanation).foregroundStyle(.white.opacity(0.8));ForEach(diagnosticCase.takeaways,id:\.self){Label($0,systemImage:"checkmark.circle.fill").font(.subheadline).foregroundStyle(.secondary)}}.card()
        Button("Return to garage",action:done).buttonStyle(PrimaryButtonStyle())
    }.padding() } } }
}

struct RepairOrderView:View{
    @Environment(\.dismiss) private var dismiss; let order:RepairOrder
    var body:some View{NavigationStack{ScrollView{VStack(alignment:.leading,spacing:0){Text("REPAIR ORDER").font(.caption.weight(.black)).tracking(3).foregroundStyle(.black.opacity(0.5));Text(order.vehicle).font(.title.bold()).foregroundStyle(.black).padding(.top,7);Text("\(order.mileage.formatted()) miles").foregroundStyle(.black.opacity(0.6));ROField(title:"CUSTOMER STATES",text:order.complaint);ROField(title:"SERVICE WRITER NOTES",text:order.notes);Text("Verify the concern, gather evidence, identify the root cause, and choose the repair that fixes it.").font(.footnote).foregroundStyle(.black.opacity(0.55)).padding(.top,20)}.padding(25).background(Color(red:0.95,green:0.92,blue:0.82)).clipShape(RoundedRectangle(cornerRadius:22)).padding()}.background(Color.black).navigationTitle("Work Order").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.topBarTrailing){Button("Start"){dismiss()}.fontWeight(.bold).tint(accent)}}}}
}

struct TrainingView:View{
    @State private var quiz:QuizSeed?; let areas=[("A1","Engine Repair"),("A2","Automatic Transmission"),("A3","Manual Drivetrain"),("A4","Steering & Suspension"),("A5","Brakes"),("A6","Electrical"),("A7","HVAC"),("A8","Engine Performance")]
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:11){Text("ASE-style practice").font(.title.bold());Text("Independent practice content; not affiliated with or endorsed by ASE.").font(.footnote).foregroundStyle(.secondary).padding(.bottom,5);ForEach(areas,id:\.0){area in Button{quiz = .init(area:area.0,title:area.1,questions:AppData.shared.aseQuestions.filter{$0.area==area.0}.shuffled())}label:{HStack{Text(area.0).font(.headline.monospaced()).foregroundStyle(accent).frame(width:38);Text(area.1).font(.headline).foregroundStyle(.white);Spacer();Image(systemName:"chevron.right").foregroundStyle(.secondary)}.padding(15).background(panel).clipShape(RoundedRectangle(cornerRadius:16))}.buttonStyle(.plain)}}.padding()}.background(Color.black.ignoresSafeArea()).navigationTitle("Training").fullScreenCover(item:$quiz){seed in NavigationStack{QuizView(seed:seed)}}}
}
struct QuizSeed:Identifiable{let id=UUID();let area:String;let title:String;let questions:[ASEQuestion]}
struct QuizView: View {
    @Environment(\.dismiss) private var dismiss
    let seed: QuizSeed
    @State private var index = 0
    @State private var selected: String?
    @State private var correct = 0
    @State private var finished = false

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
                            ChoiceRow(text: "\(choice.id). \(choice.text)", selected: selected == choice.id) { selected = choice.id }
                        }
                        Button(index == seed.questions.count - 1 ? "Finish" : "Next question") {
                            if selected?.lowercased() == question.correctID.lowercased() { correct += 1 }
                            selected = nil
                            if index == seed.questions.count - 1 { finished = true } else { index += 1 }
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

struct ToolboxView:View{var body:some View{List(AppData.shared.toolReferences){tool in VStack(alignment:.leading,spacing:7){Label(tool.name,systemImage:tool.symbol).font(.headline).foregroundStyle(.white);Text(tool.use).font(.subheadline).foregroundStyle(.secondary);Text("SHOP TIP  ·  \(tool.tip)").font(.caption).foregroundStyle(accent)}.padding(.vertical,7).listRowBackground(Color.white.opacity(0.05))}.scrollContentBackground(.hidden).background(Color.black).navigationTitle("Toolbox")}}

struct ProfileView:View{
    @EnvironmentObject var progress:ProgressStore; @EnvironmentObject var purchases:PurchaseManager; @State private var confirmReset=false
    var body:some View{List{Section{VStack(alignment:.leading,spacing:6){Text(progress.rank).font(.title2.bold());Text("\(progress.points) XP · \(progress.completedCases) cases · \(progress.accuracy)% accuracy").foregroundStyle(.secondary)}};Section("ACCESS"){if purchases.isPro{Label("MasterMechanic Pro active",systemImage:"crown.fill").foregroundStyle(accent)}else{NavigationLink("Unlock Pro levels"){ProView()}};Button("Restore purchases"){Task{await purchases.restore()}}};Section("PRIVACY & SUPPORT"){NavigationLink("Privacy"){PrivacyView()};Link("Manage Apple subscription",destination:URL(string:"https://apps.apple.com/account/subscriptions")!);Text("No MasterMechanic account is required. Progress is stored on this device.").font(.footnote).foregroundStyle(.secondary)};Section("DATA"){Button("Reset local progress",role:.destructive){confirmReset=true}};Section{Text("Independent educational simulator. Always use vehicle-specific service information and safety procedures for real repairs.").font(.footnote).foregroundStyle(.secondary)}}.scrollContentBackground(.hidden).background(Color.black).navigationTitle("Profile").confirmationDialog("Reset all local progress?",isPresented:$confirmReset,titleVisibility:.visible){Button("Reset progress",role:.destructive){progress.reset()}}.alert("Store",isPresented:Binding(get:{purchases.message != nil},set:{if !$0{purchases.message=nil}})){Button("OK"){purchases.message=nil}}message:{Text(purchases.message ?? "")}}
}

struct ProView:View{
    @EnvironmentObject var purchases:PurchaseManager
    var body:some View{ScrollView{VStack(spacing:18){Image(systemName:"crown.fill").font(.system(size:62)).foregroundStyle(accent).padding(.top,20);Text("MasterMechanic Pro").font(.largeTitle.bold());Text("Unlock Technician through Diagnostic Specialist cases.").foregroundStyle(.secondary).multilineTextAlignment(.center);VStack(alignment:.leading,spacing:10){Label("All six diagnostic levels",systemImage:"checkmark.circle.fill");Label("Intermittent, electrical and network faults",systemImage:"checkmark.circle.fill");Label("Future Pro case packs while subscribed",systemImage:"checkmark.circle.fill")}.card();Text(purchases.product.map{"\($0.displayPrice) / month"} ?? "$6.99 / month").font(.title2.bold());Text("Auto-renewable subscription billed through your Apple ID. Cancel anytime in Apple subscription settings.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center);Button(purchases.isPro ? "Pro is active":"Start Pro"){Task{await purchases.buyPro()}}.buttonStyle(PrimaryButtonStyle()).disabled(purchases.isPro);Button("Restore purchases"){Task{await purchases.restore()}}.foregroundStyle(accent);HStack(spacing:18){NavigationLink("Privacy policy"){PrivacyView()};Link("Terms of Use",destination:AppConfig.termsURL)}.font(.footnote)}.padding()}.background(Color.black.ignoresSafeArea()).navigationTitle("Pro").navigationBarTitleDisplayMode(.inline)}
}

struct PrivacyView:View{var body:some View{ScrollView{VStack(alignment:.leading,spacing:15){Text("Privacy").font(.largeTitle.bold());Text("MasterMechanic does not require an app account. Simulator progress and settings are stored locally on the device. StoreKit supplies purchase entitlement status so the app can determine whether Pro is active.");Text("This native build does not use Base44, Stripe, third-party advertising SDKs, analytics SDKs, or cross-app tracking.");Text("Before App Store submission, replace the placeholder privacy URL in AppConfig with your published policy and make the App Privacy answers match the shipping build.");Link("Open published privacy policy",destination:AppConfig.privacyURL).foregroundStyle(accent)}.foregroundStyle(.white.opacity(0.85)).padding()}.background(Color.black.ignoresSafeArea())}}

struct StatTile:View{let value:String;let label:String;let symbol:String;var body:some View{VStack(spacing:5){Image(systemName:symbol).foregroundStyle(accent);Text(value).font(.headline.monospacedDigit());Text(label).font(.caption2).foregroundStyle(.secondary)}.frame(maxWidth:.infinity).padding(.vertical,13).background(panel).clipShape(RoundedRectangle(cornerRadius:15))}}
struct SectionHeader:View{let title:String;let subtitle:String;init(_ title:String,_ subtitle:String){self.title=title;self.subtitle=subtitle};var body:some View{HStack{Text(title).font(.caption.weight(.black)).tracking(1.7);Spacer();Text(subtitle).font(.caption2.bold()).foregroundStyle(.secondary)}}}
struct ChoiceRow:View{let text:String;let selected:Bool;let action:()->Void;var body:some View{Button(action:action){HStack(spacing:11){Image(systemName:selected ? "largecircle.fill.circle":"circle").foregroundStyle(selected ? accent:Color.secondary);Text(text).foregroundStyle(.white).multilineTextAlignment(.leading);Spacer()}.padding(13).background(selected ? accent.opacity(0.09):panel).overlay(RoundedRectangle(cornerRadius:14).stroke(selected ? accent.opacity(0.65):outline)).clipShape(RoundedRectangle(cornerRadius:14))}.buttonStyle(.plain)}}
struct ResultLine:View{let label:String;let value:String;let pass:Bool?;var body:some View{HStack(alignment:.top){VStack(alignment:.leading,spacing:2){Text(label.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary);Text(value).font(.subheadline)};Spacer();if let pass{Image(systemName:pass ? "checkmark.circle.fill":"xmark.circle.fill").foregroundStyle(pass ? accent:.red)}}}}
struct ROField:View{let title:String;let text:String;var body:some View{VStack(alignment:.leading,spacing:6){Text(title).font(.caption.weight(.black)).tracking(1.3).foregroundStyle(.black.opacity(0.5));Text(text).foregroundStyle(.black)}.padding(.top,21)}}
struct PrimaryButtonStyle:ButtonStyle{func makeBody(configuration:Configuration)->some View{configuration.label.font(.headline).frame(maxWidth:.infinity).padding(.vertical,14).background(accent.opacity(configuration.isPressed ? 0.72:1)).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius:15))}}
private extension View{func card()->some View{padding(16).background(panel).clipShape(RoundedRectangle(cornerRadius:19)).overlay(RoundedRectangle(cornerRadius:19).stroke(outline))}}
