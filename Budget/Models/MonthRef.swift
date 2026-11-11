import Foundation

/// A specific month of a specific year.
struct MonthRef: Hashable, Comparable {
    let year: Int
    let month: Int

    /// Out-of-range months roll over, so `MonthRef(year: 2025, month: 13)` is January 2026.
    init(year: Int, month: Int) {
        let index = year * 12 + (month - 1)
        let y = index >= 0 ? index / 12 : (index - 11) / 12
        self.year = y
        self.month = index - y * 12 + 1
    }

    init(containing day: Day) {
        self.init(year: day.year, month: day.month)
    }

    var firstDay: Day { Day(uncheckedYear: year, month: month, day: 1) }

    var lastDay: Day { adding(months: 1).firstDay.adding(days: -1) }

    func contains(_ day: Day) -> Bool { day.year == year && day.month == month }

    func adding(months: Int) -> MonthRef { MonthRef(year: year, month: month + months) }

    static func < (lhs: MonthRef, rhs: MonthRef) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}
