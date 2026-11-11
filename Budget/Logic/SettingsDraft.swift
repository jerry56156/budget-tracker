import Foundation

struct CategoryDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
    /// The name this category had when Settings was opened; nil for newly added ones.
    var originalName: String?
}

struct FixedItemDraft: Identifiable, Equatable {
    let id = UUID()
    var name = ""
    var amount = ""
    var frequencyDays = ""
    var nextDueDate = Date()
}

/// The text typed into the Settings screen, before validation.
struct SettingsDraft: Equatable {
    var currencyCode = ""
    var currencySymbol = ""
    var monthlyBudget = ""
    var payAmount = ""
    var payFrequencyDays = ""
    var nextPayDate = Date()
    var categories: [CategoryDraft] = []
    var fixedItems: [FixedItemDraft] = []

    struct Output: Equatable {
        var settings: Settings
        var fixedItems: [FixedItem]
        /// Old category name → new name, for categories that were renamed.
        var renames: [String: String]
    }

    struct Invalid: Error, Equatable {
        let messages: [String]
    }

    init() {}

    init(settings: Settings, fixedItems: [FixedItem]) {
        currencyCode = settings.currencyCode
        currencySymbol = settings.currencySymbol
        monthlyBudget = settings.monthlyBudget.map(Money.plain) ?? ""
        payAmount = settings.payAmount.map(Money.plain) ?? ""
        payFrequencyDays = settings.payFrequencyDays.map(String.init) ?? ""
        nextPayDate = settings.nextPayDate?.date() ?? Date()
        categories = settings.categories.map { CategoryDraft(name: $0, originalName: $0) }
        self.fixedItems = fixedItems.map {
            FixedItemDraft(name: $0.name, amount: Money.plain($0.amount),
                           frequencyDays: String($0.frequencyDays), nextDueDate: $0.nextDueDate.date())
        }
    }

    /// Checks every field. Throws `Invalid` listing all problems, or returns values ready to save.
    func validated() throws -> Output {
        var problems: [String] = []

        func check<T>(_ label: String, _ body: () throws -> T) -> T? {
            do { return try body() } catch {
                problems.append("\(label) \(error.localizedDescription).")
                return nil
            }
        }

        var settings = Settings()
        settings.currencyCode = currencyCode.trimmingCharacters(in: .whitespaces)
        settings.currencySymbol = currencySymbol.trimmingCharacters(in: .whitespaces)
        if settings.currencyCode.isEmpty { problems.append("Currency code is required.") }
        settings.monthlyBudget = check("Monthly budget") { try Validation.amount(monthlyBudget) }
        settings.payAmount = check("Pay amount") { try Validation.amount(payAmount) }
        settings.payFrequencyDays = check("Pay frequency") { try Validation.wholeDays(payFrequencyDays) }
        settings.nextPayDate = Day(date: nextPayDate)

        var seen = Set<String>()
        var renames: [String: String] = [:]
        for category in categories {
            let name = category.name.trimmingCharacters(in: .whitespaces)
            if name.isEmpty {
                problems.append("Category names cannot be empty.")
            } else if name.unicodeScalars.contains(",") {
                problems.append("Category “\(name)” cannot contain a comma.")
            } else if !seen.insert(name.lowercased()).inserted {
                problems.append("Category “\(name)” is listed more than once.")
            } else {
                settings.categories.append(name)
                if let original = category.originalName, original != name { renames[original] = name }
            }
        }
        if categories.isEmpty { problems.append("Add at least one category.") }

        var items: [FixedItem] = []
        for (index, draft) in fixedItems.enumerated() {
            let name = draft.name.trimmingCharacters(in: .whitespaces)
            let label = name.isEmpty ? "Fixed item \(index + 1)" : "Fixed item “\(name)”"
            if name.isEmpty { problems.append("\(label): name is required.") }
            let amount = check("\(label): amount") { try Validation.amount(draft.amount) }
            let frequency = check("\(label): frequency") { try Validation.wholeDays(draft.frequencyDays) }
            if !name.isEmpty, let amount, let frequency {
                items.append(FixedItem(name: name, amount: amount, frequencyDays: frequency,
                                       nextDueDate: Day(date: draft.nextDueDate)))
            }
        }

        guard problems.isEmpty else { throw Invalid(messages: problems) }
        return Output(settings: settings, fixedItems: items, renames: renames)
    }
}
