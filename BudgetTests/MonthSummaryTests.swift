import XCTest
@testable import Budget

final class MonthSummaryTests: XCTestCase {
    private let january = MonthRef(year: 2025, month: 1)

    private let sample = [
        expense("2025-01-05", "12.50", "Food", "a"),
        expense("2025-01-20", "30", "Fun", "b"),
        expense("2025-01-20", "7.25", "Food", "c"),
        expense("2025-02-01", "100", "Food", "d"),
        expense("2024-12-31", "9", "Fun", "e"),
    ]

    func testTotalsOnlyCountTheChosenMonth() {
        let summary = MonthSummary(month: january, expenses: sample, budget: dec("200"))
        XCTAssertEqual(summary.spent, dec("49.75"))
        XCTAssertEqual(summary.remaining, dec("150.25"))
        XCTAssertEqual(summary.fraction ?? 0, 0.24875, accuracy: 0.000001)
        XCTAssertEqual(summary.status, .normal)
    }

    func testExpensesAreNewestFirstWithLatestAddedFirstOnTheSameDay() {
        let summary = MonthSummary(month: january, expenses: sample, budget: nil)
        XCTAssertEqual(summary.expenses.map(\.description), ["c", "b", "a"])
    }

    func testCategoryTotalsAreSortedByAmountThenName() {
        let summary = MonthSummary(month: january, expenses: sample, budget: nil)
        XCTAssertEqual(summary.categoryTotals, [
            CategoryTotal(category: "Fun", total: dec("30")),
            CategoryTotal(category: "Food", total: dec("19.75")),
        ])

        let tied = MonthSummary(month: january, expenses: [
            expense("2025-01-01", "5", "Zebra"), expense("2025-01-02", "5", "Apple"), expense("2025-01-03", "9", "Mango"),
        ], budget: nil)
        XCTAssertEqual(tied.categoryTotals.map(\.category), ["Mango", "Apple", "Zebra"])
    }

    func testOtherMonthsAndEmptyMonths() {
        let february = MonthSummary(month: MonthRef(year: 2025, month: 2), expenses: sample, budget: dec("200"))
        XCTAssertEqual(february.spent, dec("100"))
        XCTAssertEqual(february.expenses.map(\.description), ["d"])

        let march = MonthSummary(month: MonthRef(year: 2025, month: 3), expenses: sample, budget: dec("200"))
        XCTAssertEqual(march.spent, 0)
        XCTAssertEqual(march.remaining, dec("200"))
        XCTAssertTrue(march.expenses.isEmpty)
        XCTAssertTrue(march.categoryTotals.isEmpty)
        XCTAssertEqual(march.status, .normal)
    }

    func testStatusTurnsAmberAtEightyPercentAndRedOverOneHundred() {
        func status(spent: String) -> BudgetStatus {
            MonthSummary(month: january, expenses: [expense("2025-01-10", spent, "Food")], budget: dec("100")).status
        }
        XCTAssertEqual(status(spent: "79.99"), .normal)
        XCTAssertEqual(status(spent: "80"), .warning)
        XCTAssertEqual(status(spent: "99.99"), .warning)
        XCTAssertEqual(status(spent: "100"), .warning)
        XCTAssertEqual(status(spent: "100.01"), .over)
    }

    func testOverBudgetGivesNegativeRemaining() {
        let summary = MonthSummary(month: january, expenses: [expense("2025-01-10", "130", "Food")], budget: dec("100"))
        XCTAssertEqual(summary.remaining, dec("-30"))
        XCTAssertEqual(summary.fraction ?? 0, 1.3, accuracy: 0.000001)
    }

    func testNoBudgetSet() {
        let summary = MonthSummary(month: january, expenses: sample, budget: nil)
        XCTAssertNil(summary.remaining)
        XCTAssertNil(summary.fraction)
        XCTAssertEqual(summary.status, .normal)
    }

    func testCentsAddUpExactly() {
        let many = (1...100).map { _ in expense("2025-01-15", "0.10", "Food") }
        XCTAssertEqual(MonthSummary(month: january, expenses: many, budget: nil).spent, dec("10"))
    }
}
