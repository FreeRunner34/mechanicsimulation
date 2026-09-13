import Foundation

private struct Base44Envelope: Decodable {
    let entities: [Base44Entity]
}

private struct Base44Entity: Decodable {
    let id: String
    let difficulty: String
    let brand: String?
    let caseData: Base44Case

    enum CodingKeys: String, CodingKey {
        case id, difficulty, brand
        case caseData = "case"
    }
}

private struct Base44Case: Decodable {
    let repairOrder: Base44RepairOrder
    let tools: [Base44Tool]
    let inspections: [Base44Inspection]
    let diagnosis: Base44Diagnosis
    let finalDiagnosis: Base44FinalDiagnosis
}

private struct Base44RepairOrder: Decodable {
    let vehicle: String
    let mileage: Int
    let customerComplaint: String
    let serviceWriterNotes: String
}

private struct Base44Tool: Decodable {
    let id: String
    let name: String
    let hint: String
}

private struct Base44Inspection: Decodable {
    let id: String
    let view: String
    let label: String
    let toolId: String
    let productive: Bool
    let finding: String
}

private struct Base44Diagnosis: Decodable {
    let rootCauses: [Base44Choice]
    let repairs: [Base44Choice]
    let explanation: String
}

private struct Base44Choice: Decodable {
    let id: String
    let text: String
    let correct: Bool
}

private struct Base44FinalDiagnosis: Decodable {
    let rootCause: String
    let correctRepair: String
    let keyTakeaways: [String]
}

enum ImportedBase44Cases {
    private static let resourceNames = [
        "Base44RepairCases01",
        "Base44RepairCases02",
        "Base44RepairCases03",
        "Base44RepairCases04",
        "Base44RepairCases05",
        "Base44RepairCases06",
        "Base44RepairCases07",
        "Base44RepairCases08"
    ]

    static func load() -> [DiagnosticCase] {
        resourceNames.flatMap(loadResource(named:))
    }

    private static func loadResource(named name: String) -> [DiagnosticCase] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(Base44Envelope.self, from: data) else {
            return []
        }
        return envelope.entities.compactMap(convert)
    }

    private static func convert(_ entity: Base44Entity) -> DiagnosticCase? {
        guard let difficulty = mapDifficulty(entity.difficulty) else { return nil }

        var toolMap: [String: DiagnosticTool] = [:]
        for tool in entity.caseData.tools {
            toolMap[tool.id] = DiagnosticTool(
                id: tool.id,
                name: tool.name,
                symbol: symbol(for: tool.id),
                hint: tool.hint
            )
        }

        // Some historical Base44 cases referenced a test tool in an inspection
        // without listing it on the tool cart. Add it so every imported RO is playable.
        for inspection in entity.caseData.inspections where toolMap[inspection.toolId] == nil {
            toolMap[inspection.toolId] = fallbackTool(for: inspection.toolId)
        }

        let tools = toolMap.values.sorted { lhs, rhs in
            toolOrder(lhs.id) < toolOrder(rhs.id)
        }

        let inspections = entity.caseData.inspections.compactMap { item -> Inspection? in
            guard let view = mapView(item.view) else { return nil }
            return Inspection(
                id: "\(entity.id)-\(item.id)",
                view: view,
                label: item.label,
                toolID: item.toolId,
                productive: item.productive,
                finding: item.finding
            )
        }

        let causes = entity.caseData.diagnosis.rootCauses.map {
            DiagnosisChoice(id: "\(entity.id)-cause-\($0.id)", text: $0.text, correct: $0.correct)
        }
        let repairs = entity.caseData.diagnosis.repairs.map {
            DiagnosisChoice(id: "\(entity.id)-repair-\($0.id)", text: $0.text, correct: $0.correct)
        }

        guard !inspections.isEmpty,
              causes.contains(where: \.correct),
              repairs.contains(where: \.correct) else { return nil }

        return DiagnosticCase(
            id: "base44-\(entity.id)",
            difficulty: difficulty,
            brand: entity.brand ?? inferredBrand(from: entity.caseData.repairOrder.vehicle),
            repairOrder: RepairOrder(
                vehicle: entity.caseData.repairOrder.vehicle,
                mileage: entity.caseData.repairOrder.mileage,
                complaint: entity.caseData.repairOrder.customerComplaint,
                notes: entity.caseData.repairOrder.serviceWriterNotes
            ),
            tools: tools,
            inspections: inspections,
            causes: causes,
            repairs: repairs,
            explanation: entity.caseData.diagnosis.explanation,
            rootCause: entity.caseData.finalDiagnosis.rootCause,
            correctRepair: entity.caseData.finalDiagnosis.correctRepair,
            takeaways: entity.caseData.finalDiagnosis.keyTakeaways
        )
    }

    private static func mapDifficulty(_ value: String) -> Difficulty? {
        switch value.lowercased() {
        case "entry level": return .entry
        case "apprentice": return .apprentice
        case "technician": return .technician
        case "senior specialist", "senior technician": return .senior
        case "master technician": return .master
        case "diagnostic specialist": return .diagnostic
        default: return nil
        }
    }

    private static func mapView(_ value: String) -> BayView? {
        switch value.lowercased() {
        case "under_hood", "under hood": return .underHood
        case "under_car", "under vehicle", "under car": return .underCar
        case "cockpit", "driver seat": return .cockpit
        case "exterior", "road": return .exterior
        default: return nil
        }
    }

    private static func inferredBrand(from vehicle: String) -> String? {
        let lower = vehicle.lowercased()
        if lower.contains("nisshin") { return "Nisshin Motors" }
        if lower.contains("stellar") || lower.contains("smc") { return "Stellar Motors Corp" }
        if lower.contains("bayern") { return "Bayern Werke" }
        if lower.contains("kestrel") { return "Kestrel Automotive" }
        if lower.contains("aeon") { return "Aeon Mobility" }
        return nil
    }

    private static func symbol(for id: String) -> String {
        switch id {
        case "flashlight": return "flashlight.on.fill"
        case "scan_tool": return "waveform.path.ecg.rectangle"
        case "multimeter": return "gauge.with.dots.needle.33percent"
        case "pressure_gauge": return "gauge.open.with.lines.needle.33percent"
        case "stethoscope": return "ear.fill"
        case "smoke_machine": return "aqi.medium"
        case "test_drive": return "road.lanes"
        case "test_light": return "lightbulb.fill"
        default: return "wrench.and.screwdriver.fill"
        }
    }

    private static func fallbackTool(for id: String) -> DiagnosticTool {
        switch id {
        case "stethoscope": return .init(id:id, name:"Mechanic's Stethoscope", symbol:symbol(for:id), hint:"Listen for localized mechanical or injector noise.")
        case "test_light": return .init(id:id, name:"Test Light", symbol:symbol(for:id), hint:"Quickly verify whether power is present in a circuit.")
        case "scan_tool": return .init(id:id, name:"Diagnostic Scan Tool", symbol:symbol(for:id), hint:"Read codes, module data and live PIDs.")
        case "flashlight": return .init(id:id, name:"Inspection Light", symbol:symbol(for:id), hint:"Inspect visible components, wiring, leaks and damage.")
        case "multimeter": return .init(id:id, name:"Digital Multimeter", symbol:symbol(for:id), hint:"Measure voltage, resistance and continuity.")
        case "pressure_gauge": return .init(id:id, name:"Pressure Gauge", symbol:symbol(for:id), hint:"Measure fuel, compression, cooling or hydraulic pressure.")
        case "smoke_machine": return .init(id:id, name:"Smoke Machine", symbol:symbol(for:id), hint:"Locate intake, boost and EVAP leaks.")
        case "test_drive": return .init(id:id, name:"Road Test", symbol:symbol(for:id), hint:"Reproduce the concern under operating load.")
        default: return .init(id:id, name:id.replacingOccurrences(of:"_", with:" ").capitalized, symbol:symbol(for:id), hint:"Use this diagnostic tool to gather evidence.")
        }
    }

    private static func toolOrder(_ id: String) -> Int {
        ["scan_tool", "flashlight", "multimeter", "test_light", "pressure_gauge", "stethoscope", "smoke_machine", "test_drive"].firstIndex(of: id) ?? 99
    }
}
