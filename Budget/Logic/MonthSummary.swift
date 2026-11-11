import Foundation

struct CategoryTotal: Equatable, Identifiable {
    let category: String
    let total: Decimal
    var id: String { category }
}

enum BudgetStatus: Equatable {
    case normal, warning, over
}

/// Spending for one month: the expenses, totals, and how they compare to the budget.
struct MonthSummary {
    /// Fraction of the budget at which the progress bar turns amber (80%).
    static let warningFraction = Decimal(8) / Decimal(10)

    let month: MonthRef
    /// Expenses in the month, newest first. Same-day expenses show the most recently added first.
    let expenses: [Expense]
    let spent: Decimal
    let budget: Decimal?
    /// Per-category totals, largest first.
    let categoryTotals: [CategoryTotal]

    init(month: MonthRef, expenses all: [Expense], budget: Decimal?) {
        self.month = month
        self.budget = budget
        let inMonth = all.enumerated().filter { month.contains($0.element.date) }
        self.expenses = inMonth
            .sorted { a, b in
                a.element.date != b.element.date ? a.element.date > b.element.date : a.offset > b.offset
            }
            .map(\.element)
        self.spent = inMonth.reduce(Decimal(0)) { $0 + $1.element.amount }
        var totals: [String: Decimal] = [:]
        for (_, expense) in inMonth { totals[expense.category, default: 0] += expense.amount }
        self.categoryTotals = totals
            .map { CategoryTotal(category: $0.key, total: $0.value) }
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.category < $1.category }
    }

    /// Budget minus spending; negative when over budget. Nil if no budget is set.
    var remaining: Decimal? { budget.map { $0 - spent } }

    /// Spending as a fraction of the budget (1.0 = 100%). Nil if no budget is set.
    var fraction: Double? {
        guard let budget, budget > 0 else { return nil }
        return NSDecimalNumber(decimal: spent / budget).doubleValue
    }

    var status: BudgetStatus {
        guard let budget, budget > 0 else { return .normal }
        if spent > budget { return .over }
        if spent >= budget * MonthSummary.warningFraction { return .warning }
        return .normal
    }
}
