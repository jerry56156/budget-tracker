import XCTest
@testable import Budget

final class DataStoreTests: XCTestCase {
    private func makeStore() throws -> DataStore {
        DataStore(directory: try makeTemporaryDirectory(for: self).appendingPathComponent("Budget", isDirectory: true))
    }

    func testFirstLaunchCreatesThreeFilesWithHeadersAndNoValues() throws {
        let store = try makeStore()
        try store.ensureFilesExist()

        XCTAssertEqual(try store.read(.expenses), "date,amount,category,description\n")
        XCTAssertEqual(try store.read(.fixedItems), "name,amount,frequency_days,next_due_date\n")
        XCTAssertEqual(try store.read(.settings), """
        key,value
        currency,
        currency_symbol,
        monthly_budget,
        pay_amount,
        pay_frequency_days,
        next_pay_date,
        categories,

        """)
    }

    func testExistingFilesAreNotOverwritten() throws {
        let store = try makeStore()
        try store.ensureFilesExist()
        try store.write("date,amount,category,description\n2025-01-05,3,Food,x\n", to: .expenses)
        try store.ensureFilesExist()
        XCTAssertEqual(try store.read(.expenses), "date,amount,category,description\n2025-01-05,3,Food,x\n")
    }

    func testWriteReplacesContentAndLeavesNoTemporaryFiles() throws {
        let store = try makeStore()
        try store.ensureFilesExist()
        try store.write("first\n", to: .expenses)
        try store.write("second\n", to: .expenses)

        XCTAssertEqual(try store.read(.expenses), "second\n")
        let names = try FileManager.default.contentsOfDirectory(atPath: store.directory.path).sorted()
        XCTAssertEqual(names, ["expenses.csv", "fixed_items.csv", "settings.csv"])
    }

    func testDefaultFolderIsBudgetInsideDocumentsUnlessOverridden() {
        XCTAssertTrue(DataStore.defaultDirectory(environment: [:]).path.hasSuffix("/Documents/Budget"))
        let overridden = DataStore.defaultDirectory(environment: [DataStore.directoryOverrideVariable: "/tmp/elsewhere"])
        XCTAssertEqual(overridden.path, "/tmp/elsewhere")
    }
}
