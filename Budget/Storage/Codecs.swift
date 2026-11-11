import Foundation

/// The result of reading one data file.
struct Loaded<Value> {
    var value: Value
    /// One warning per row that could not be understood.
    var warnings: [DataWarning] = []
    /// The raw fields of rows that could not be understood. They are written back
    /// to the file on every save so nothing is ever lost.
    var preserved: [[String]] = []
}

struct RowError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private enum RowSupport {
    /// All rows after the header. A missing header is tolerated: the first row is then data.
    static func dataRows(_ text: String, header: [String]) -> [CSVRow] {
        var rows = CSV.parse(text)
        if let first = rows.first,
           first.fields.map({ $0.trimmingCharacters(in: .whitespaces).lowercased() }) == header {
            rows.removeFirst()
        }
        return rows
    }

    static func checkShape(_ row: CSVRow, columns: [String]) throws {
        if row.unterminatedQuote {
            throw RowError(message: "a value opens a quote (\") that is never closed")
        }
        if row.fields.count != columns.count {
            throw RowError(message: "expected \(columns.count) columns (\(columns.joined(separator: ", "))) but found \(row.fields.count)")
        }
    }

    static func column<T>(_ name: String, _ body: () throws -> T) throws -> T {
        do { return try body() } catch {
            throw RowError(message: "\(name) \(error.localizedDescription)")
        }
    }
}

enum ExpenseCodec {
    static let header = ["date", "amount", "category", "description"]

    static func decode(_ text: String, file: String) -> Loaded<[Expense]> {
        var result = Loaded<[Expense]>(value: [])
        for row in RowSupport.dataRows(text, header: header) {
            do {
                try RowSupport.checkShape(row, columns: header)
                let date = try RowSupport.column("date") { try Validation.date(row.fields[0]) }
                let amount = try RowSupport.column("amount") { try Validation.amount(row.fields[1]) }
                result.value.append(Expense(date: date, amount: amount,
                                            category: row.fields[2].trimmingCharacters(in: .whitespaces),
                                            description: row.fields[3]))
            } catch {
                result.warnings.append(DataWarning(file: file, line: row.line, message: error.localizedDescription))
                result.preserved.append(row.fields)
            }
        }
        return result
    }

    static func encode(_ expenses: [Expense], preserved: [[String]] = []) -> String {
        CSV.encode([header]
            + expenses.map { [$0.date.iso, Money.plain($0.amount), $0.category, $0.description] }
            + preserved)
    }
}

enum FixedItemCodec {
    static let header = ["name", "amount", "frequency_days", "next_due_date"]

    static func decode(_ text: String, file: String) -> Loaded<[FixedItem]> {
        var result = Loaded<[FixedItem]>(value: [])
        for row in RowSupport.dataRows(text, header: header) {
            do {
                try RowSupport.checkShape(row, columns: header)
                let name = row.fields[0].trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { throw RowError(message: "name is required") }
                let amount = try RowSupport.column("amount") { try Validation.amount(row.fields[1]) }
                let frequency = try RowSupport.column("frequency_days") { try Validation.wholeDays(row.fields[2]) }
                let due = try RowSupport.column("next_due_date") { try Validation.date(row.fields[3]) }
                result.value.append(FixedItem(name: name, amount: amount, frequencyDays: frequency, nextDueDate: due))
            } catch {
                result.warnings.append(DataWarning(file: file, line: row.line, message: error.localizedDescription))
                result.preserved.append(row.fields)
            }
        }
        return result
    }

    static func encode(_ items: [FixedItem], preserved: [[String]] = []) -> String {
        CSV.encode([header]
            + items.map { [$0.name, Money.plain($0.amount), String($0.frequencyDays), $0.nextDueDate.iso] }
            + preserved)
    }
}

enum SettingsCodec {
    static let header = ["key", "value"]

    enum Key: String, CaseIterable {
        case currency
        case currencySymbol = "currency_symbol"
        case monthlyBudget = "monthly_budget"
        case payAmount = "pay_amount"
        case payFrequencyDays = "pay_frequency_days"
        case nextPayDate = "next_pay_date"
        case categories
    }

    static func decode(_ text: String, file: String) -> Loaded<Settings> {
        var result = Loaded<Settings>(value: Settings())
        var seen = Set<Key>()
        for row in RowSupport.dataRows(text, header: header) {
            func warn(_ message: String) {
                result.warnings.append(DataWarning(file: file, line: row.line, message: message))
            }
            do {
                try RowSupport.checkShape(row, columns: header)
            } catch {
                warn(error.localizedDescription)
                result.preserved.append(row.fields)
                continue
            }
            let name = row.fields[0].trimmingCharacters(in: .whitespaces)
            let value = row.fields[1].trimmingCharacters(in: .whitespaces)
            guard let key = Key(rawValue: name) else {
                // Unknown keys are kept as they are, so other tools can add their own.
                result.preserved.append(row.fields)
                continue
            }
            if !seen.insert(key).inserted {
                warn("“\(name)” appears more than once; the later value is used")
            }
            do {
                try apply(key, value, to: &result.value)
            } catch {
                warn("\(name) \(error.localizedDescription); it is treated as not set")
            }
        }
        return result
    }

    private static func apply(_ key: Key, _ value: String, to settings: inout Settings) throws {
        switch key {
        case .currency: settings.currencyCode = value
        case .currencySymbol: settings.currencySymbol = value
        case .monthlyBudget: settings.monthlyBudget = value.isEmpty ? nil : try Validation.amount(value)
        case .payAmount: settings.payAmount = value.isEmpty ? nil : try Validation.amount(value)
        case .payFrequencyDays: settings.payFrequencyDays = value.isEmpty ? nil : try Validation.wholeDays(value)
        case .nextPayDate: settings.nextPayDate = value.isEmpty ? nil : try Validation.date(value)
        case .categories:
            var unique: [String] = []
            for part in value.unicodeScalars.split(separator: ",") {
                let category = String(part).trimmingCharacters(in: .whitespaces)
                if !category.isEmpty && !unique.contains(category) { unique.append(category) }
            }
            settings.categories = unique
        }
    }

    static func encode(_ settings: Settings, preserved: [[String]] = []) -> String {
        let rows: [[String]] = Key.allCases.map { key in
            let value: String
            switch key {
            case .currency: value = settings.currencyCode
            case .currencySymbol: value = settings.currencySymbol
            case .monthlyBudget: value = settings.monthlyBudget.map(Money.plain) ?? ""
            case .payAmount: value = settings.payAmount.map(Money.plain) ?? ""
            case .payFrequencyDays: value = settings.payFrequencyDays.map(String.init) ?? ""
            case .nextPayDate: value = settings.nextPayDate?.iso ?? ""
            case .categories: value = settings.categories.joined(separator: ",")
            }
            return [key.rawValue, value]
        }
        return CSV.encode([header] + rows + preserved)
    }
}
