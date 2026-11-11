import XCTest
@testable import Budget

final class CashFlowTests: XCTestCase {
    private var settings: Settings {
        var settings = Settings()
        settings.monthlyBudget = dec("500")
        settings.payAmount = dec("1000")
        settings.payFrequencyDays = 14
        settings.nextPayDate = day("2025-01-03")
        return settings
    }

    private let fixedItems = [
        FixedItem(name: "Rent", amount: dec("800"), frequencyDays: 30, nextDueDate: day("2025-01-01")),
        FixedItem(name: "Streaming", amount: dec("10"), frequencyDays: 7, nextDueDate: day("2025-01-05")),
    ]

    func testMonthWithThreePayDatesAndRentFallingTwice() {
        let flow = CashFlowSummary(month: MonthRef(year: 2025, month: 1), settings: settings, fixedItems: fixedItems)
        XCTAssertEqual(flow.payDates, [day("2025-01-03"), day("2025-01-17"), day("2025-01-31")])
        XCTAssertEqual(flow.income, dec("3000"))
        XCTAssertEqual(flow.dueItems.map(\.name), ["Rent", "Streaming", "Streaming", "Streaming", "Streaming", "Rent"])
        XCTAssertEqual(flow.dueItems.first?.date, day("2025-01-01"))
        XCTAssertEqual(flow.dueItems.last?.date, day("2025-01-31"))
        XCTAssertEqual(flow.fixedTotal, dec("1640"))
        XCTAssertEqual(flow.spendingBudget, dec("500"))
        XCTAssertEqual(flow.leftover, dec("860"))
    }

    func testFollowingMonth() {
        let flow = CashFlowSummary(month: MonthRef(year: 2025, month: 2), settings: settings, fixedItems: fixedItems)
        XCTAssertEqual(flow.payDates, [day("2025-02-14"), day("2025-02-28")])
        XCTAssertEqual(flow.income, dec("2000"))
        XCTAssertEqual(flow.fixedTotal, dec("40")) // the 30-day rent cycle skips February
        XCTAssertEqual(flow.leftover, dec("1460"))
    }

    func testPastMonthIsWorkedOutBackwardsFromTheStoredDates() {
        let flow = CashFlowSummary(month: MonthRef(year: 2024, month: 12), settings: settings, fixedItems: fixedItems)
        XCTAssertEqual(flow.payDates, [day("2024-12-06"), day("2024-12-20")])
        XCTAssertEqual(flow.income, dec("2000"))
        XCTAssertEqual(flow.fixedTotal, dec("850"))
        XCTAssertEqual(flow.leftover, dec("650"))
    }

    func testLeftoverCanBeNegative() {
        var lowPay = settings
        lowPay.payAmount = dec("100")
        let flow = CashFlowSummary(month: MonthRef(year: 2025, month: 2), settings: lowPay, fixedItems: fixedItems)
        XCTAssertEqual(flow.leftover, dec("-340"))
    }

    func testNoFixedItems() {
        let flow = CashFlowSummary(month: MonthRef(year: 2025, month: 1), settings: settings, fixedItems: [])
        XCTAssertTrue(flow.dueItems.isEmpty)
        XCTAssertEqual(flow.fixedTotal, 0)
        XCTAssertEqual(flow.leftover, dec("2500"))
    }

    func testBlankSettingsGiveZeroes() {
        let flow = CashFlowSummary(month: MonthRef(year: 2025, month: 1), settings: Settings(), fixedItems: [])
        XCTAssertTrue(flow.payDates.isEmpty)
        XCTAssertEqual(flow.income, 0)
        XCTAssertEqual(flow.leftover, 0)
    }
}
