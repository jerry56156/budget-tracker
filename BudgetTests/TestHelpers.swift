import XCTest
@testable import Budget

func dec(_ text: String) -> Decimal {
    Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
}

func day(_ iso: String) -> Day {
    Day(iso: iso)!
}

func expense(_ date: String, _ amount: String, _ category: String, _ description: String = "") -> Expense {
    Expense(date: day(date), amount: dec(amount), category: category, description: description)
}

/// An expense's values without its identity, for comparing lists.
func rowValues(_ expenses: [Expense]) -> [[String]] {
    expenses.map { [$0.date.iso, Money.plain($0.amount), $0.category, $0.description] }
}

/// A fresh, empty folder that is deleted when the test finishes.
func makeTemporaryDirectory(for testCase: XCTestCase) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("BudgetTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    testCase.addTeardownBlock { try? FileManager.default.removeItem(at: url) }
    return url
}

func assertThrows<T>(_ expected: ValidationError, file: StaticString = #filePath, line: UInt = #line,
                     _ body: () throws -> T) {
    XCTAssertThrowsError(try body(), file: file, line: line) { error in
        XCTAssertEqual(error as? ValidationError, expected, file: file, line: line)
    }
}
