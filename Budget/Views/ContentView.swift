import SwiftUI
import Combine

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            if !model.warnings.isEmpty {
                WarningsView(warnings: model.warnings)
                    .padding([.horizontal, .top])
            }
            content
        }
        .frame(minWidth: 780, minHeight: 560)
        .toolbar { toolbarContent }
        .sheet(isPresented: addExpenseBinding) { ExpenseFormView(existing: nil) }
        .sheet(item: $model.editingExpense) { expense in ExpenseFormView(existing: expense) }
        .sheet(isPresented: $model.showingSettings) { SettingsView() }
        .alert("Couldn’t save", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .task { model.load() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Pick up edits made to the CSV files in another app.
            model.reloadIfIdle()
        }
    }

    /// While Settings is open, the Add Expense form is shown on top of it instead (see SettingsView).
    private var addExpenseBinding: Binding<Bool> {
        Binding(
            get: { model.showingAddExpense && !model.showingSettings },
            set: { model.showingAddExpense = $0 }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    @ViewBuilder private var content: some View {
        if let loadError = model.loadError {
            ContentUnavailableView {
                Label("Couldn’t read your data", systemImage: "exclamationmark.triangle")
            } description: {
                Text(loadError)
            } actions: {
                Button("Try Again") { model.load() }
                Button("Open Data Folder in Finder") { NSWorkspace.shared.open(model.store.directory) }
            }
        } else if !model.hasLoaded {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !model.settings.isComplete {
            ContentUnavailableView {
                Label("Set up your budget", systemImage: "slider.horizontal.3")
            } description: {
                Text("Nothing is filled in for you. Enter your currency, monthly budget, pay schedule and categories in Settings to get started.")
            } actions: {
                Button("Open Settings…") { model.showingSettings = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            DashboardView()
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        @Bindable var model = model
        ToolbarItemGroup(placement: .navigation) {
            Button {
                model.selectedMonth = model.selectedMonth.adding(months: -1)
            } label: {
                Label("Previous Month", systemImage: "chevron.left")
            }
            .help("Previous month")

            Picker("Month", selection: $model.selectedMonth) {
                ForEach(model.monthOptions, id: \.self) { month in
                    Text(month.title).tag(month)
                }
            }
            .pickerStyle(.menu)
            .help("Choose a month")

            Button {
                model.selectedMonth = model.selectedMonth.adding(months: 1)
            } label: {
                Label("Next Month", systemImage: "chevron.right")
            }
            .help("Next month")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button("This Month") { model.selectedMonth = model.currentMonth }
                .disabled(model.selectedMonth == model.currentMonth)
            Button {
                model.requestAddExpense()
            } label: {
                Label("Add Expense", systemImage: "plus")
            }
            .disabled(!model.canAddExpense)
            .help("Add expense (⌘N)")
            Button {
                model.showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .disabled(!model.hasLoaded)
            .help("Settings (⌘,)")
        }
    }
}

/// Lists rows in the data files that could not be read, with file name and line number.
struct WarningsView: View {
    let warnings: [DataWarning]
    @State private var expanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(warnings, id: \.self) { warning in
                        Text("\(warning.file), line \(warning.line): \(warning.message)")
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                    Text("These rows are kept in the file but left out of the totals. Fix them in a text editor, then choose File ▸ Reload Data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
            .frame(maxHeight: 110)
        } label: {
            Label(warnings.count == 1
                    ? "1 row in your data files couldn’t be read"
                    : "\(warnings.count) rows in your data files couldn’t be read",
                  systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
