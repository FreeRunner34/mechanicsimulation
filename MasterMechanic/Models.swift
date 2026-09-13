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
    static let privacyURL = URL(string: "https://example.com/mastermechanic/privacy")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
