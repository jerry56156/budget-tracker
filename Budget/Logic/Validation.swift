import Foundation

enum ValidationError: Error, Equatable, LocalizedError {
    case empty
    case notANumber
    case notPositive
    case tooManyDecimals
    case notAWholeNumber
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .empty: return "is required"
        case .notANumber: return "must be a number like 12 or 12.50 (digits and a decimal point only)"
        case .notPositive: return "must be greater than zero"
        case .tooManyDecimals: return "can have at most 2 decimal places"
        case .notAWholeNumber: return "must be a whole number of 1 or more"
        case .invalidDate: return "must be a real date written as YYYY-MM-DD"
        }
    }
}

enum Validation {
    static let maxDecimalPlaces = 2
    private static let maxIntegerDigits = 12

    private static func isDigits(_ s: Substring) -> Bool {
        !s.isEmpty && s.unicodeScalars.allSatisfy { (48...57).contains($0.value) }
    }

    /// A positive money amount with at most two decimal places.
    static func amount(_ text: String) throws -> Decimal {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw ValidationError.empty }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, isDigits(parts[0]), parts[0].count <= maxIntegerDigits else {
            throw ValidationError.notANumber
        }
        if parts.count == 2 {
            guard isDigits(parts[1]) else { throw ValidationError.notANumber }
            guard parts[1].count <= maxDecimalPlaces else { throw ValidationError.tooManyDecimals }
        }
        guard let value = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX")),
              !value.isNaN else { throw ValidationError.notANumber }
        guard value > 0 else { throw ValidationError.notPositive }
        return value
    }

    /// A frequency in days: a whole number, 1 or more.
    static func wholeDays(_ text: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw ValidationError.empty }
        guard isDigits(Substring(trimmed)), trimmed.count <= 6, let value = Int(trimmed), value >= 1 else {
            throw ValidationError.notAWholeNumber
        }
        return value
    }

    static func date(_ text: String) throws -> Day {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw ValidationError.empty }
        guard let day = Day(iso: trimmed) else { throw ValidationError.invalidDate }
        return day
    }
}
