import Foundation

// Models.swift combines the built-in and expanded native catalogs with `+`.
// This exact-element overload keeps that existing call site intact while adding
// the migrated Base44 catalog once, with ID de-duplication.
func + (lhs: [DiagnosticCase], rhs: [DiagnosticCase]) -> [DiagnosticCase] {
    var result = lhs
    result.append(contentsOf: rhs)

    let existingIDs = Set(result.map(\.id))
    result.append(contentsOf: ImportedBase44Cases.load().filter { !existingIDs.contains($0.id) })
    return result
}
