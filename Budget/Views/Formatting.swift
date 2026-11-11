import Foundation

/// Locale-aware text for dates. The words and order come from the user's system settings.
enum DateText {
    private static func formatter(_ configure: (DateFormatter) -> Void) -> DateFormatter {
        let calendar = Day.localGregorian
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        configure(formatter)
        return formatter
    }

    static func month(_ month: MonthRef) -> String {
        formatter { $0.setLocalizedDateFormatFromTemplate("MMMMyyyy") }.string(from: month.firstDay.date())
    }

    static func day(_ day: Day) -> String {
        formatter { $0.dateStyle = .medium; $0.timeStyle = .none }.string(from: day.date())
    }

    static func shortDay(_ day: Day) -> String {
        formatter { $0.setLocalizedDateFormatFromTemplate("MMMd") }.string(from: day.date())
    }
}

extension MonthRef {
    var title: String { DateText.month(self) }
}
