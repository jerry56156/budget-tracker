import XCTest
@testable import Budget

final class SettingsDraftTests: XCTestCase {
    private func validDraft() -> SettingsDraft {
        var draft = SettingsDraft()
        draft.currencyCode = " ABC "
        draft.currencySymbol = "¤"
        draft.monthlyBudget = "500"
        draft.payAmount = "1000.50"
        draft.payFrequencyDays = "14"
        draft.nextPayDate = day("2025-01-03").date()
        draft.categories = [CategoryDraft(name: "Food", originalName: "Food"),
                            CategoryDraft(name: " Fun ", originalName: nil)]
        draft.fixedItems = [FixedItemDraft(name: "Rent", amount: "800", frequencyDays: "30",
                                           nextDueDate: day("2025-01-01").date())]
        return draft
    }

    func testValidDraftProducesSettingsReadyToSave() throws {
        let output = try validDraft().validated()
        XCTAssertEqual(output.settings.currencyCode, "ABC")
        XCTAssertEqual(output.settings.currencySymbol, "¤")
        XCTAssertEqual(output.settings.monthlyBudget, dec("500"))
        XCTAssertEqual(output.settings.payAmount, dec("1000.5"))
        XCTAssertEqual(output.settings.payFrequencyDays, 14)
        XCTAssertEqual(output.settings.nextPayDate, day("2025-01-03"))
        XCTAssertEqual(output.settings.categories, ["Food", "Fun"])
        XCTAssertTrue(output.settings.isComplete)
        XCTAssertEqual(output.fixedItems.map(\.name), ["Rent"])
        XCTAssertEqual(output.fixedItems.map(\.nextDueDate), [day("2025-01-01")])
        XCTAssertTrue(output.renames.isEmpty)
    }

    func testRenamesAreRecorded() throws {
        var draft = validDraft()
        draft.categories[0].name = "Groceries"
        XCTAssertEqual(try draft.validated().renames, ["Food": "Groceries"])
    }

    func testEveryProblemIsListed() {
        var draft = SettingsDraft()
        draft.monthlyBudget = "-1"
        draft.payAmount = "1.999"
        draft.payFrequencyDays = "0"
        draft.categories = [CategoryDraft(name: "A,B", originalName: nil),
                            CategoryDraft(name: "Food", originalName: nil),
                            CategoryDraft(name: "food", originalName: nil),
                            CategoryDraft(name: "  ", originalName: nil)]
        draft.fixedItems = [FixedItemDraft(name: "", amount: "x", frequencyDays: "", nextDueDate: Date())]

        XCTAssertThrowsError(try draft.validated()) { error in
            let messages = (error as? SettingsDraft.Invalid)?.messages ?? []
            // currency, budget, pay amount, pay frequency, 3 bad categories, 3 fixed-item problems
            XCTAssertEqual(messages.count, 10, "\(messages)")
        }
    }

    func testAtLeastOneCategoryIsRequired() {
        var draft = validDraft()
        draft.categories = []
        XCTAssertThrowsError(try draft.validated())
    }

    func testDraftIsFilledFromSavedSettings() throws {
        let output = try validDraft().validated()
        let draft = SettingsDraft(settings: output.settings, fixedItems: output.fixedItems)
        XCTAssertEqual(draft.monthlyBudget, "500")
        XCTAssertEqual(draft.payAmount, "1000.5")
        XCTAssertEqual(draft.payFrequencyDays, "14")
        XCTAssertEqual(draft.categories.map(\.originalName), ["Food", "Fun"])
        XCTAssertEqual(try draft.validated().settings, output.settings)
    }
}
