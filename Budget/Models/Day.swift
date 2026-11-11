import Foundation

/// A calendar day in the Gregorian calendar, with no time of day or time zone.
/// All schedule math is done on `ordinal` (days since 1970-01-01) so it is exact.
struct Day: Hashable, Comparable {
    let year: Int
    let month: Int
    let day: Int

    init?(year: Int, month: Int, day: Int) {
        guard (1...9999).contains(year), (1...12).contains(month),
              day >= 1, day <= Day.daysIn(month: month, year: year) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// For values already known to form a real date.
    init(uncheckedYear year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Days since 1970-01-01 (can be negative).
    var ordinal: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    init(ordinal: Int) {
        let z = ordinal + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let m = mp < 10 ? mp + 3 : mp - 9
        self.year = yoe + era * 400 + (m <= 2 ? 1 : 0)
        self.month = m
        self.day = doy - (153 * mp + 2) / 5 + 1
    }

    static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2: return isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    func adding(days: Int) -> Day { Day(ordinal: ordinal + days) }

    static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // MARK: Text form used in the CSV files (yyyy-MM-dd)

    init?(iso text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.unicodeScalars.allSatisfy { (48...57).contains($0.value) } }),
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    var iso: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    // MARK: Bridging to Foundation dates (for date pickers and display)

    static var localGregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    init(date: Date, calendar: Calendar = Day.localGregorian) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = c.year ?? 1970
        self.month = c.month ?? 1
        self.day = c.day ?? 1
    }

    /// Noon on this day, so daylight-saving shifts can never move it to a neighbouring day.
    func date(calendar: Calendar = Day.localGregorian) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    static var today: Day { Day(date: Date()) }
}
