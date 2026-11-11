import XCTest
@testable import Budget

final class DayTests: XCTestCase {
    func testKnownOrdinals() {
        XCTAssertEqual(day("1970-01-01").ordinal, 0)
        XCTAssertEqual(day("1969-12-31").ordinal, -1)
        XCTAssertEqual(day("2000-03-01").ordinal, 11_017)
        XCTAssertEqual(Day(ordinal: 0).adding(days: 365), day("1971-01-01"))
    }

    func testOrdinalRoundTripsAcrossManyYears() {
        var previous = Day(ordinal: -40_001)
        for n in -40_000...80_000 {
            let d = Day(ordinal: n)
            XCTAssertEqual(d.ordinal, n)
            XCTAssertNotNil(Day(year: d.year, month: d.month, day: d.day), "\(d.iso) is not a real date")
            XCTAssertLessThan(previous, d)
            previous = d
        }
    }

    func testLeapYears() {
        XCTAssertNotNil(Day(year: 2024, month: 2, day: 29))
        XCTAssertNotNil(Day(year: 2000, month: 2, day: 29))
        XCTAssertNil(Day(year: 2025, month: 2, day: 29))
        XCTAssertNil(Day(year: 1900, month: 2, day: 29))
        XCTAssertNil(Day(year: 2025, month: 4, day: 31))
        XCTAssertNil(Day(year: 2025, month: 0, day: 1))
    }

    func testTextForm() {
        XCTAssertEqual(day("2025-03-09").iso, "2025-03-09")
        XCTAssertEqual(Day(iso: "2025-12-31"), Day(year: 2025, month: 12, day: 31))
        XCTAssertNil(Day(iso: "2025-1-5"))
        XCTAssertNil(Day(iso: "2025-02-30"))
        XCTAssertNil(Day(iso: "2025-01-05 "))
        XCTAssertNil(Day(iso: ""))
    }

    func testConvertingToAndFromDatesKeepsTheSameDay() {
        // Includes days where clocks change in many time zones.
        for iso in ["2025-03-09", "2025-03-30", "2025-11-02", "2024-02-29", "2025-12-31", "2025-01-01"] {
            XCTAssertEqual(Day(date: day(iso).date()), day(iso))
        }
    }

    func testMonthBoundaries() {
        XCTAssertEqual(MonthRef(year: 2024, month: 2).lastDay, day("2024-02-29"))
        XCTAssertEqual(MonthRef(year: 2025, month: 2).lastDay, day("2025-02-28"))
        XCTAssertEqual(MonthRef(year: 2025, month: 12).lastDay, day("2025-12-31"))
        XCTAssertEqual(MonthRef(year: 2025, month: 12).firstDay, day("2025-12-01"))
        XCTAssertTrue(MonthRef(year: 2025, month: 1).contains(day("2025-01-31")))
        XCTAssertFalse(MonthRef(year: 2025, month: 1).contains(day("2025-02-01")))
        XCTAssertFalse(MonthRef(year: 2025, month: 1).contains(day("2024-01-15")))
    }

    func testMonthArithmeticRollsOverYears() {
        XCTAssertEqual(MonthRef(year: 2025, month: 13), MonthRef(year: 2026, month: 1))
        XCTAssertEqual(MonthRef(year: 2025, month: 0), MonthRef(year: 2024, month: 12))
        XCTAssertEqual(MonthRef(year: 2025, month: 1).adding(months: -1), MonthRef(year: 2024, month: 12))
        XCTAssertEqual(MonthRef(year: 2025, month: 11).adding(months: 14), MonthRef(year: 2027, month: 1))
        XCTAssertEqual(MonthRef(containing: day("2025-06-30")), MonthRef(year: 2025, month: 6))
        XCTAssertLessThan(MonthRef(year: 2024, month: 12), MonthRef(year: 2025, month: 1))
    }
}
