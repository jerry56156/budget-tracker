import Foundation

/// A recurring obligation from fixed_items.csv (rent, loan payment, subscription, ...).
struct FixedItem: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var amount: Decimal
    var frequencyDays: Int
    var nextDueDate: Day
}

/// One row of expenses.csv.
struct Expense: Identifiable, Equatable {
    var id = UUID()
    var date: Day
    var amount: Decimal
    var category: String
    var description: String
}

/// A problem found while reading a data file. The offending row is kept, never dropped.
struct DataWarning: Hashable {
    let file: String
    let line: Int
    let message: String
}
