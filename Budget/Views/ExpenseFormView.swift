import SwiftUI

/// Adds a new expense, or edits `existing`.
struct ExpenseFormView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let existing: Expense?

    @State private var amountText: String
    @State private var category: String
    @State private var descriptionText: String
    @State private var date: Date
    @State private var problem: String?
    @State private var finished = false
    @FocusState private var amountFocused: Bool

    init(existing: Expense?) {
        self.existing = existing
        _amountText = State(initialValue: existing.map { Money.plain($0.amount) } ?? "")
        _category = State(initialValue: existing?.category ?? "")
        _descriptionText = State(initialValue: existing?.description ?? "")
        _date = State(initialValue: existing?.date.date() ?? Date())
    }

    /// Categories from Settings, plus this expense's own category if it has since been removed.
    private var categoryOptions: [String] {
        var options = model.settings.categories
        if let existing, !existing.category.isEmpty, !options.contains(existing.category) {
            options.append(existing.category)
        }
        return options
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Amount (\(model.settings.currencyCode))", text: $amountText)
                    .focused($amountFocused)
                Picker("Category", selection: $category) {
                    ForEach(categoryOptions, id: \.self) { Text($0).tag($0) }
                }
                TextField("Description", text: $descriptionText)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                if let problem {
                    Label(problem, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .onSubmit(submit)

            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(existing == nil ? "Add Expense" : "Save", action: submit)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 440)
        .onAppear {
            if !categoryOptions.contains(category) { category = categoryOptions.first ?? "" }
            amountFocused = true
        }
    }

    private func submit() {
        guard !finished else { return }
        do {
            let amount: Decimal
            do { amount = try Validation.amount(amountText) } catch {
                throw RowError(message: "Amount \(error.localizedDescription).")
            }
            guard !category.isEmpty else { throw RowError(message: "Choose a category.") }
            let day: Day
            do { day = try Validation.date(Day(date: date).iso) } catch {
                throw RowError(message: "Date \(error.localizedDescription).")
            }

            if var expense = existing {
                expense.date = day
                expense.amount = amount
                expense.category = category
                expense.description = descriptionText
                try model.updateExpense(expense)
            } else {
                try model.addExpense(Expense(date: day, amount: amount, category: category, description: descriptionText))
                // Show the month the new expense landed in.
                model.selectedMonth = MonthRef(containing: day)
            }
            finished = true
            dismiss()
        } catch {
            problem = error.localizedDescription
        }
    }
}
