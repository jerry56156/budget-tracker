import SwiftUI

/// The summaries for the selected month.
struct DashboardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let summary = model.summary
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BudgetCard(summary: summary)
                HStack(alignment: .top, spacing: 16) {
                    CashFlowCard(cashFlow: model.cashFlow)
                    CategoryTotalsCard(totals: summary.categoryTotals)
                }
                ExpensesCard(expenses: summary.expenses)
            }
            .padding()
        }
    }
}

struct Card<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
        } label: {
            Text(title).font(.headline)
        }
    }
}

// MARK: Spending against the budget

struct BudgetCard: View {
    @Environment(AppModel.self) private var model
    let summary: MonthSummary

    var body: some View {
        Card("Spending in \(summary.month.title)") {
            HStack(alignment: .top, spacing: 36) {
                stat("Spent so far", model.money(summary.spent))
                if let remaining = summary.remaining {
                    if remaining < 0 {
                        stat("Over budget by", model.money(-remaining), color: .red)
                    } else {
                        stat("Remaining", model.money(remaining))
                    }
                }
                if let budget = summary.budget {
                    stat("Monthly budget", model.money(budget))
                }
            }
            if let fraction = summary.fraction {
                BudgetProgressBar(fraction: fraction, status: summary.status)
                Text("\(fraction.formatted(.percent.precision(.fractionLength(0)))) of budget used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stat(_ label: String, _ value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2).fontWeight(.semibold).monospacedDigit().foregroundStyle(color)
        }
    }
}

/// Green normally, amber from 80% of the budget, red once over it.
struct BudgetProgressBar: View {
    let fraction: Double
    let status: BudgetStatus

    private var color: Color {
        switch status {
        case .normal: return .green
        case .warning: return .orange
        case .over: return .red
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule().fill(color)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 10)
        .accessibilityElement()
        .accessibilityLabel("Budget used")
        .accessibilityValue(fraction.formatted(.percent.precision(.fractionLength(0))))
    }
}

// MARK: Cash flow

struct CashFlowCard: View {
    @Environment(AppModel.self) private var model
    let cashFlow: CashFlowSummary

    var body: some View {
        Card("Cash flow for \(cashFlow.month.title)") {
            line("Pay expected", cashFlow.income)
            detail(payDetail)

            line("Fixed items due", -cashFlow.fixedTotal)
            if cashFlow.dueItems.isEmpty {
                detail("Nothing due this month")
            }
            ForEach(Array(cashFlow.dueItems.enumerated()), id: \.offset) { _, item in
                HStack {
                    Text("\(item.name) · \(DateText.shortDay(item.date))")
                    Spacer()
                    Text(model.money(item.amount)).monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
            }

            line("Spending budget", -cashFlow.spendingBudget)
            Divider()
            HStack {
                Text("Left over").fontWeight(.semibold)
                Spacer()
                Text(model.money(cashFlow.leftover))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(cashFlow.leftover < 0 ? Color.red : Color.primary)
            }
        }
    }

    private var payDetail: String {
        guard !cashFlow.payDates.isEmpty else { return "No pay dates this month" }
        let dates = cashFlow.payDates.map(DateText.shortDay).joined(separator: ", ")
        return "\(cashFlow.payDates.count) × \(model.money(cashFlow.payAmount)) · \(dates)"
    }

    private func line(_ label: String, _ amount: Decimal) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(model.money(amount)).monospacedDigit()
        }
    }

    private func detail(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 12)
    }
}

// MARK: Category totals

struct CategoryTotalsCard: View {
    @Environment(AppModel.self) private var model
    let totals: [CategoryTotal]

    var body: some View {
        Card("By category") {
            if totals.isEmpty {
                Text("No spending this month.").foregroundStyle(.secondary)
            }
            ForEach(totals) { total in
                HStack {
                    Text(total.category.isEmpty ? "No category" : total.category)
                    Spacer()
                    Text(model.money(total.total)).monospacedDigit()
                }
            }
        }
    }
}

// MARK: Expense list

struct ExpensesCard: View {
    @Environment(AppModel.self) private var model
    let expenses: [Expense]
    @State private var pendingDelete: Expense?

    var body: some View {
        Card("Expenses") {
            if expenses.isEmpty {
                Text("No expenses in this month.").foregroundStyle(.secondary)
            }
            ForEach(expenses) { expense in
                row(expense)
                if expense.id != expenses.last?.id { Divider() }
            }
        }
        .confirmationDialog(
            "Delete this expense?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { expense in
            Button("Delete", role: .destructive) { model.delete(expense) }
            Button("Cancel", role: .cancel) {}
        } message: { expense in
            Text("\(model.money(expense.amount)) · \(expense.category) · \(DateText.day(expense.date)). This can’t be undone.")
        }
    }

    private func row(_ expense: Expense) -> some View {
        HStack(spacing: 12) {
            Text(DateText.day(expense.date))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.description.isEmpty ? "No description" : expense.description)
                    .foregroundStyle(expense.description.isEmpty ? Color.secondary : Color.primary)
                    .lineLimit(2)
                Text(expense.category.isEmpty ? "No category" : expense.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(model.money(expense.amount)).monospacedDigit()
            Button {
                model.editingExpense = expense
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .help("Edit")
            Button {
                pendingDelete = expense
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .help("Delete")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }
}
