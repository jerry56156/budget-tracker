import XCTest
@testable import Budget

final class ScheduleTests: XCTestCase {
    private func dates(_ anchor: String, every days: Int, in year: Int, _ month: Int) -> [String] {
        Schedule.occurrences(anchor: day(anchor), frequencyDays: days, in: MonthRef(year: year, month: month)).map(\.iso)
    }

    func testFortnightlyPayInTheAnchorMonth() {
        XCTAssertEqual(dates("2025-01-03", every: 14, in: 2025, 1), ["2025-01-03", "2025-01-17", "2025-01-31"])
    }

    func testFortnightlyPayInLaterMonths() {
        XCTAssertEqual(dates("2025-01-03", every: 14, in: 2025, 2), ["2025-02-14", "2025-02-28"])
        XCTAssertEqual(dates("2025-01-03", every: 14, in: 2025, 3), ["2025-03-14", "2025-03-28"])
    }

    func testScheduleExtendsBackwardsForPastMonths() {
        XCTAssertEqual(dates("2025-01-03", every: 14, in: 2024, 12), ["2024-12-06", "2024-12-20"])
        XCTAssertEqual(dates("2025-01-03", every: 14, in: 2024, 11), ["2024-11-08", "2024-11-22"])
    }

    func testThirtyDayCycleCanSkipAShortMonthOrLandTwiceInALongOne() {
        XCTAssertEqual(dates("2025-01-31", every: 30, in: 2025, 2), [])
        XCTAssertEqual(dates("2025-01-31", every: 30, in: 2025, 3), ["2025-03-02"])
        XCTAssertEqual(dates("2025-01-01", every: 30, in: 2025, 1), ["2025-01-01", "2025-01-31"])
    }

    func testWeeklyAcrossALeapDay() {
        XCTAssertEqual(dates("2024-02-29", every: 7, in: 2024, 2),
                       ["2024-02-01", "2024-02-08", "2024-02-15", "2024-02-22", "2024-02-29"])
        XCTAssertEqual(dates("2024-02-29", every: 7, in: 2024, 3),
                       ["2024-03-07", "2024-03-14", "2024-03-21", "2024-03-28"])
    }

    func testDailyHitsEveryDayOfTheMonth() {
        XCTAssertEqual(dates("2030-06-15", every: 1, in: 2025, 2).count, 28)
        XCTAssertEqual(dates("2020-06-15", every: 1, in: 2024, 2).count, 29)
    }

    func testAnchorOnFirstAndLastDayOfMonthIsIncluded() {
        XCTAssertEqual(dates("2025-04-01", every: 400, in: 2025, 4), ["2025-04-01"])
        XCTAssertEqual(dates("2025-04-30", every: 400, in: 2025, 4), ["2025-04-30"])
        XCTAssertEqual(dates("2025-05-01", every: 400, in: 2025, 4), [])
        XCTAssertEqual(dates("2025-03-31", every: 400, in: 2025, 4), [])
    }

    func testLongCyclesStayAlignedWithTheAnchorInBothDirections() {
        let anchor = day("2030-06-15")
        for frequency in [2, 3, 10, 28, 31, 90, 365] {
            for offset in -30...30 {
                let month = MonthRef(year: 2030, month: 6).adding(months: offset)
                let found = Schedule.occurrences(anchor: anchor, frequencyDays: frequency, in: month)
                XCTAssertEqual(found, found.sorted())
                for d in found {
                    XCTAssertTrue(month.contains(d))
                    XCTAssertEqual((d.ordinal - anchor.ordinal) % frequency, 0)
                }
                // Nothing in the month is missed.
                let expected = (month.firstDay.ordinal...month.lastDay.ordinal)
                    .filter { ($0 - anchor.ordinal) % frequency == 0 }.count
                XCTAssertEqual(found.count, expected)
            }
        }
    }

    func testInvalidFrequencyGivesNoDates() {
        XCTAssertEqual(dates("2025-01-03", every: 0, in: 2025, 1), [])
        XCTAssertEqual(dates("2025-01-03", every: -7, in: 2025, 1), [])
    }
}
