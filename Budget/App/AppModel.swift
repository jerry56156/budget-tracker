import Foundation
import Observation

enum AppModelError: LocalizedError {
    case notLoaded
    case changedOnDisk(String)
    case expenseMissing

    var errorDescription: String? {
        switch self {
        case .notLoaded:
            return "Your data files could not be read, so nothing was saved. Fix the problem and reload."
        case .changedOnDisk(let file):
            return "\(file) was changed outside the app since it was last read, so nothing was saved. Choose File ▸ Reload Data and try again."
        case .expenseMissing:
            return "That expense is no longer in the file. It may have been changed outside the app."
        }
    }
}

/// The app's state: everything read from the CSV files, plus what the window is showing.
@MainActor
@Observable
final class AppModel {
    let store: DataStore

    private(set) var settings = Settings()
    private(set) var fixedItems: [FixedItem] = []
    private(set) var expenses: [Expense] = []
    private(set) var warnings: [DataWarning] = []
    private(set) var loadError: String?
    private(set) var hasLoaded = false

    var selectedMonth = MonthRef(containing: .today)
    var showingAddExpense = false
    var showingSettings = false
    var editingExpense: Expense?
    var errorMessage: String?

    /// Rows the app could not understand, kept so they are written back on every save.
    @ObservationIgnored private var preserved: [DataStore.File: [[String]]] = [:]
    /// Exactly what was last read from each file, used to detect outside edits before saving.
    @ObservationIgnored private var loadedText: [DataStore.File: String] = [:]

    init(store: DataStore) {
        self.store = store
    }

    // MARK: Loading

    func load() {
        do {
            try store.ensureFilesExist()
            var text: [DataStore.File: String] = [:]
            for file in DataStore.File.allCases { text[file] = try store.read(file) }

            let loadedSettings = SettingsCodec.decode(text[.settings] ?? "", file: DataStore.File.settings.rawValue)
            let loadedItems = FixedItemCodec.decode(text[.fixedItems] ?? "", file: DataStore.File.fixedItems.rawValue)
            let loadedExpenses = ExpenseCodec.decode(text[.expenses] ?? "", file: DataStore.File.expenses.rawValue)

            settings = loadedSettings.value
            fixedItems = loadedItems.value
            expenses = Self.keepingIDs(from: expenses, in: loadedExpenses.value)
            warnings = loadedSettings.warnings + loadedItems.warnings + loadedExpenses.warnings
            preserved = [
                .settings: loadedSettings.preserved,
                .fixedItems: loadedItems.preserved,
                .expenses: loadedExpenses.preserved,
            ]
            loadedText = text
            loadError = nil
            hasLoaded = true
        } catch {
            loadError = error.localizedDescription
            hasLoaded = false
        }
    }

    /// Reloads unless a form is open (so nothing being typed is disturbed).
    func reloadIfIdle() {
        guard !showingAddExpense, !showingSettings, editingExpense == nil else { return }
        load()
    }

    /// Unchanged rows keep their identity across reloads, so the list stays stable.
    private static func keepingIDs(from old: [Expense], in new: [Expense]) -> [Expense] {
        func key(_ e: Expense) -> [String] { [e.date.iso, Money.plain(e.amount), e.category, e.description] }
        var available: [[String]: [UUID]] = [:]
        for expense in old.reversed() { available[key(expense), default: []].append(expense.id) }
        return new.map { expense in
            var expense = expense
            if let id = available[key(expense)]?.popLast() { expense.id = id }
            return expense
        }
    }

    // MARK: Saving

    private func checkUnchangedOnDisk(_ file: DataStore.File) throws {
        guard hasLoaded else { throw AppModelError.notLoaded }
        guard try store.read(file) == loadedText[file] else {
            throw AppModelError.changedOnDisk(file.rawValue)
        }
    }

    private func write(_ text: String, to file: DataStore.File) throws {
        try checkUnchangedOnDisk(file)
        try store.write(text, to: file)
        loadedText[file] = text
    }

    private func writeExpenses(_ updated: [Expense]) throws {
        try write(ExpenseCodec.encode(updated, preserved: preserved[.expenses] ?? []), to: .expenses)
    }

    func addExpense(_ expense: Expense) throws {
        try writeExpenses(expenses + [expense])
        load()
    }

    func updateExpense(_ expense: Expense) throws {
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }) else {
            throw AppModelError.expenseMissing
        }
        var updated = expenses
        updated[index] = expense
        try writeExpenses(updated)
        load()
    }

    func deleteExpense(id: UUID) throws {
        guard expenses.contains(where: { $0.id == id }) else { throw AppModelError.expenseMissing }
        try writeExpenses(expenses.filter { $0.id != id })
        load()
    }

    /// Deletes and reports any failure through `errorMessage`.
    func delete(_ expense: Expense) {
        do { try deleteExpense(id: expense.id) } catch { errorMessage = error.localizedDescription }
    }

    func saveSettings(_ output: SettingsDraft.Output) throws {
        let renamed = expenses.map { expense -> Expense in
            var expense = expense
            if let newName = output.renames[expense.category] { expense.category = newName }
            return expense
        }
        let rewriteExpenses = renamed != expenses

        // Check every file first so an outside edit cannot leave a half-applied save.
        try checkUnchangedOnDisk(.settings)
        try checkUnchangedOnDisk(.fixedItems)
        if rewriteExpenses { try checkUnchangedOnDisk(.expenses) }

        defer { load() }
        if rewriteExpenses { try writeExpenses(renamed) }
        try write(FixedItemCodec.encode(output.fixedItems, preserved: preserved[.fixedItems] ?? []), to: .fixedItems)
        try write(SettingsCodec.encode(output.settings, preserved: preserved[.settings] ?? []), to: .settings)
    }

    // MARK: What the views show

    var canAddExpense: Bool { hasLoaded && settings.isComplete }

    func requestAddExpense() {
        guard canAddExpense, editingExpense == nil else { return }
        showingAddExpense = true
    }

    var currentMonth: MonthRef { MonthRef(containing: .today) }

    /// Months offered in the month picker: every month with expenses, plus this month and the one shown.
    var monthOptions: [MonthRef] {
        Set(expenses.map { MonthRef(containing: $0.date) })
            .union([currentMonth, selectedMonth])
            .sorted(by: >)
    }

    var summary: MonthSummary {
        MonthSummary(month: selectedMonth, expenses: expenses, budget: settings.monthlyBudget)
    }

    var cashFlow: CashFlowSummary {
        CashFlowSummary(month: selectedMonth, settings: settings, fixedItems: fixedItems)
    }

    func money(_ amount: Decimal) -> String {
        Money.display(amount, symbol: settings.displaySymbol)
    }

    func expenseCount(inCategory category: String) -> Int {
        expenses.filter { $0.category == category }.count
    }
}
