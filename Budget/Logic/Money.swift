import Foundation

enum Money {
    /// Plain text used in the CSV files and edit fields, e.g. "12.5". Always uses "." as the decimal point.
    static func plain(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }

    /// Text for display, e.g. "$1,234.50" or "-$20.00", using the symbol from Settings.
    /// Digit grouping and the decimal mark follow the system's number format.
    static func display(_ amount: Decimal, symbol: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = Validation.maxDecimalPlaces
        formatter.maximumFractionDigits = Validation.maxDecimalPlaces
        let magnitude = amount < 0 ? -amount : amount
        let number = formatter.string(from: NSDecimalNumber(decimal: magnitude)) ?? plain(magnitude)
        return (amount < 0 ? "-" : "") + symbol + number
    }
}
