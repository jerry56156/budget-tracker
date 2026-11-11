import XCTest
@testable import Budget

@MainActor
final class AppModelTests: XCTestCase {
    private func makeModel() throws -> AppModel {
        let directory = try makeTemporaryDirectory(for: self).appendingPathComponent("Budget", isDirectory: true)
        return AppModel(store: DataStore(directory: directory))
    }

    func testFirstLoadCreatesFilesAndAsksForSetup() throws {
        let model = try makeModel()
        model.load()
        XCTAssertTrue(model.hasLoaded)
        XCTAssertNil(model.loadError)
        XCTAssertFalse(model.settings.isComplete)
        XCTAssertFalse(model.canAddExpense)
        XCTAssertTrue(model.expenses.isEmpty)
        XCTAssertTrue(model.fixedItems.isEmpty)
        XCTAssertTrue(model.warnings.isEmpty)
    }

    func testAddEditAndDeleteExpenseAreWrittenToDisk() throws {
        let model = try makeModel()
        model.load()

        try model.addExpense(expense("2025-01-05", "12.5", "Food", "Lunch, with \"friends\""))
        try model.addExpense(expense("2025-01-06", "3", "Fun"))
        XCTAssertEqual(try model.store.read(.expenses),
                       "date,amount,category,description\n2025-01-05,12.5,Food,\"Lunch, with \"\"friends\"\"\"\n2025-01-06,3,Fun,\n")

        var edited = model.expenses[0]
        edited.amount = dec("20")
        try model.updateExpense(edited)
        XCTAssertEqual(rowValues(model.expenses)[0], ["2025-01-05", "20", "Food", "Lunch, with \"friends\""])

        try model.deleteExpense(id: model.expenses[0].id)
        XCTAssertEqual(rowValues(model.expenses), [["2025-01-06", "3", "Fun", ""]])
        XCTAssertEqual(try model.store.read(.expenses), "date,amount,category,description\n2025-01-06,3,Fun,\n")
    }

    func testUnchangedExpensesKeepTheirIdentityAcrossReloads() throws {
        let model = try makeModel()
        model.load()
        try model.addExpense(expense("2025-01-05", "1", "Food"))
        try model.addExpense(expense("2025-01-05", "1", "Food"))
        let ids = model.expenses.map(\.id)
        XCTAssertEqual(Set(ids).count, 2)
        model.load()
        XCTAssertEqual(model.expenses.map(\.id), ids)
    }

    func testMalformedRowsAreWarnedAboutAndSurviveSaves() throws {
        let model = try makeModel()
        model.load()
        try model.store.write("date,amount,category,description\n2025-01-05,1,Food,ok\nyesterday,lots,Food,broken row\n", to: .expenses)
        model.load()

        XCTAssertEqual(model.warnings.map(\.file), ["expenses.csv"])
        XCTAssertEqual(model.warnings.map(\.line), [3])
        XCTAssertEqual(model.expenses.count, 1)

        try model.addExpense(expense("2025-01-06", "2", "Food"))
        try model.deleteExpense(id: model.expenses[0].id)

        XCTAssertTrue(try model.store.read(.expenses).contains("yesterday,lots,Food,broken row\n"))
        XCTAssertEqual(model.warnings.count, 1)
        XCTAssertEqual(rowValues(model.expenses), [["2025-01-06", "2", "Food", ""]])
    }

    func testSavingIsRefusedWhenAFileChangedOutsideTheApp() throws {
        let model = try makeModel()
        model.load()
        let outsideEdit = "date,amount,category,description\n2025-01-05,99,Food,typed in a text editor\n"
        try model.store.write(outsideEdit, to: .expenses)

        XCTAssertThrowsError(try model.addExpense(expense("2025-01-06", "2", "Food")))
        XCTAssertEqual(try model.store.read(.expenses), outsideEdit)

        model.load()
        try model.addExpense(expense("2025-01-06", "2", "Food"))
        XCTAssertEqual(model.expenses.count, 2)
    }

    func testUnreadableFileBlocksSavingInsteadOfBeingOverwritten() throws {
        let model = try makeModel()
        model.load()
        let notText = Data([0xFF, 0xFE, 0xFF, 0xFF, 0x00, 0xC3])
        try notText.write(to: model.store.url(.expenses))
        model.load()

        XCTAssertFalse(model.hasLoaded)
        XCTAssertNotNil(model.loadError)
        XCTAssertThrowsError(try model.addExpense(expense("2025-01-06", "2", "Food")))
        XCTAssertEqual(try Data(contentsOf: model.store.url(.expenses)), notText)
    }

    func testSavingSettingsRenamesCategoriesOnExpensesAndKeepsRemovedOnes() throws {
        let model = try makeModel()
        model.load()

        var draft = SettingsDraft()
        draft.currencyCode = "ABC"
        draft.monthlyBudget = "500"
        draft.payAmount = "1000"
        draft.payFrequencyDays = "14"
        draft.categories = [CategoryDraft(name: "Food", originalName: nil), CategoryDraft(name: "Fun", originalName: nil)]
        draft.fixedItems = [FixedItemDraft(name: "Rent", amount: "800", frequencyDays: "30", nextDueDate: day("2025-01-01").date())]
        try model.saveSettings(try draft.validated())

        XCTAssertTrue(model.settings.isComplete)
        XCTAssertEqual(model.settings.categories, ["Food", "Fun"])
        XCTAssertEqual(model.fixedItems.map(\.name), ["Rent"])
        XCTAssertEqual(model.fixedItems.map(\.nextDueDate), [day("2025-01-01")])

        try model.addExpense(expense("2025-01-05", "1", "Food"))
        try model.addExpense(expense("2025-01-06", "2", "Fun"))
        XCTAssertEqual(model.expenseCount(inCategory: "Fun"), 1)

        // Rename Food → Groceries and remove Fun.
        var second = SettingsDraft(settings: model.settings, fixedItems: model.fixedItems)
        second.categories[0].name = "Groceries"
        second.categories.remove(at: 1)
        try model.saveSettings(try second.validated())

        XCTAssertEqual(model.settings.categories, ["Groceries"])
        XCTAssertEqual(rowValues(model.expenses), [
            ["2025-01-05", "1", "Groceries", ""],
            ["2025-01-06", "2", "Fun", ""],
        ])
        XCTAssertEqual(model.fixedItems.map(\.name), ["Rent"])
    }
}
