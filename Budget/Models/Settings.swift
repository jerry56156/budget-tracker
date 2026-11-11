import Foundation

/// Scalar settings from settings.csv. Everything starts empty; nothing is seeded.
struct Settings: Equatable {
    var currencyCode: String = ""
    var currencySymbol: String = ""
    var monthlyBudget: Decimal?
    var payAmount: Decimal?
    var payFrequencyDays: Int?
    var nextPayDate: Day?
    var categories: [String] = []

    /// True once every value the app needs has been filled in.
    var isComplete: Bool {
        !currencyCode.isEmpty && monthlyBudget != nil && payAmount != nil
            && payFrequencyDays != nil && nextPayDate != nil && !categories.isEmpty
    }

    /// The symbol to show before amounts; falls back to the currency code.
    var displaySymbol: String {
        currencySymbol.isEmpty ? (currencyCode.isEmpty ? "" : currencyCode + " ") : currencySymbol
    }
}
