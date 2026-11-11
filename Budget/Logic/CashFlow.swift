import Foundation

/// One occurrence of a fixed item inside a month.
struct DueItem: Equatable, Identifiable {
    let name: String
    let amount: Decimal
    let date: Day
    var id: String { "\(name)|\(date.iso)" }
}

/// Expected money in and out for one month:
/// pay received − fixed items due − spending budget = left over.
struct CashFlowSummary: Equatable {
    let month: MonthRef
    let payDates: [Day]
    let payAmount: Decimal
    let dueItems: [DueItem]
    let spendingBudget: Decimal

    init(month: MonthRef, settings: Settings, fixedItems: [FixedItem]) {
        self.month = month
        self.payAmount = settings.payAmount ?? 0
        self.spendingBudget = settings.monthlyBudget ?? 0
        if let anchor = settings.nextPayDate, let frequency = settings.payFrequencyDays {
            self.payDates = Schedule.occurrences(anchor: anchor, frequencyDays: frequency, in: month)
        } else {
            self.payDates = []
        }
        self.dueItems = fixedItems
            .flatMap { item in
                Schedule.occurrences(anchor: item.nextDueDate, frequencyDays: item.frequencyDays, in: month)
                    .map { DueItem(name: item.name, amount: item.amount, date: $0) }
            }
            .sorted { $0.date != $1.date ? $0.date < $1.date : $0.name < $1.name }
    }

    var income: Decimal { payAmount * Decimal(payDates.count) }
    var fixedTotal: Decimal { dueItems.reduce(Decimal(0)) { $0 + $1.amount } }
    var leftover: Decimal { income - fixedTotal - spendingBudget }
}
