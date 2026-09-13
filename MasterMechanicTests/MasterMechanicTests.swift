import XCTest
import StoreKitTest
@testable import MasterMechanic

final class MasterMechanicTests: XCTestCase {
    func testImportedRepairOrderCountIsEighty() {
        XCTAssertEqual(ImportedBase44Cases.importedCount, 80)
    }

    func testPlayableCaseIDsAreUnique() {
        let ids = AppData.shared.playableCases.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testEveryDifficultyHasPlayableCases() {
        for difficulty in Difficulty.allCases {
            let count = AppData.shared.playableCases.filter { $0.difficulty == difficulty }.count
            XCTAssertGreaterThan(count, 0, "No playable cases for \(difficulty.rawValue)")
        }
    }

    func testEveryCaseHasAPlayableDiagnosticPath() {
        for diagnosticCase in AppData.shared.playableCases {
            XCTAssertFalse(diagnosticCase.repairOrder.vehicle.isEmpty)
            XCTAssertFalse(diagnosticCase.repairOrder.complaint.isEmpty)
            XCTAssertFalse(diagnosticCase.inspections.isEmpty)
            XCTAssertEqual(diagnosticCase.causes.filter(\.correct).count, 1, diagnosticCase.id)
            XCTAssertEqual(diagnosticCase.repairs.filter(\.correct).count, 1, diagnosticCase.id)

            let toolIDs = Set(diagnosticCase.tools.map(\.id))
            for inspection in diagnosticCase.inspections {
                XCTAssertTrue(toolIDs.contains(inspection.toolID), "\(diagnosticCase.id) is missing tool \(inspection.toolID)")
            }
        }
    }

    func testRecentCaseExclusionWorksWhenAlternativesExist() {
        for difficulty in Difficulty.allCases {
            let pool = AppData.shared.playableCases.filter { $0.difficulty == difficulty }
            guard pool.count > 1, let first = pool.first else { continue }
            for _ in 0..<25 {
                let next = AppData.shared.nextCase(difficulty: difficulty, excluding: [first.id])
                XCTAssertNotEqual(next?.id, first.id)
            }
        }
    }

    func testTrainingBankHasAtLeastSixtyQuestionsPerArea() {
        for area in ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"] {
            XCTAssertGreaterThanOrEqual(AppData.shared.trainingQuestions.filter { $0.area == area }.count, 60, area)
        }
    }

    func testPracticeTestsUseTwentyUniqueQuestionFamilies() {
        for area in ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"] {
            let questions = AppData.shared.practiceTest(area: area, questionCount: 20)
            XCTAssertEqual(questions.count, 20, area)
            XCTAssertEqual(Set(questions.map(\.id)).count, 20, area)

            let families = questions.map { question -> String in
                let parts = question.id.split(separator: "-")
                if question.id.hasPrefix("bank-"), parts.count >= 3 {
                    return parts.prefix(3).joined(separator: "-")
                }
                return question.id
            }
            XCTAssertEqual(Set(families).count, 20, "Duplicate concept family in \(area) practice test")
        }
    }

    func testDealerModeAlwaysReturnsSelectedBrand() {
        for brand in AppData.shared.brands {
            for difficulty in Difficulty.allCases {
                let next = AppData.shared.nextCase(difficulty: difficulty, dealerBrand: brand.id)
                XCTAssertEqual(next?.brand, brand.id, "Dealer Mode failed for \(brand.id) / \(difficulty.rawValue)")
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

    func testProductionURLsAreNotPlaceholders() {
        XCTAssertFalse(AppConfig.privacyURL.absoluteString.contains("example.com"))
        XCTAssertFalse(AppConfig.supportURL.absoluteString.contains("example.com"))
        XCTAssertEqual(AppConfig.proProductID, "com.freerunner34.mastermechanic.pro.monthly")
    }

    func testLocalStoreKitConfigurationCanCreateProSubscriptionTransaction() throws {
        let testSourceURL = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testSourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let configurationURL = repositoryRoot
            .appendingPathComponent("MasterMechanic")
            .appendingPathComponent("MasterMechanic.storekit")

        XCTAssertTrue(FileManager.default.fileExists(atPath: configurationURL.path))

        let session = try SKTestSession(contentsOf: configurationURL)
        session.disableDialogs = true
        session.clearTransactions()
        try session.buyProduct(productIdentifier: AppConfig.proProductID)

        XCTAssertTrue(
            session.allTransactions().contains { $0.productIdentifier == AppConfig.proProductID },
            "Local StoreKit configuration did not create the Pro subscription transaction."
        )
    }

    @MainActor
    func testProgressScoringPersistsExpectedXPAndCanReset() {
        let progress = ProgressStore()
        progress.reset()
        guard let diagnosticCase = AppData.shared.playableCases.first else {
            XCTFail("No playable case")
            return
        }

        let xp = progress.record(case: diagnosticCase, score: 80, solved: true, tests: 3, wastedTests: 0)
        let expected = Int((80.0 * diagnosticCase.difficulty.multiplier * 5.0).rounded())
        XCTAssertEqual(xp, expected)
        XCTAssertEqual(progress.points, expected)
        XCTAssertEqual(progress.completedCases, 1)
        XCTAssertEqual(progress.correctCases, 1)
        XCTAssertEqual(progress.streak, 1)

        progress.reset()
        XCTAssertEqual(progress.points, 0)
        XCTAssertEqual(progress.completedCases, 0)
        XCTAssertTrue(progress.history.isEmpty)
    }
}
