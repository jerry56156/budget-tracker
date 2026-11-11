import SwiftUI

/// Edits everything in settings.csv and fixed_items.csv. Nothing is saved until Save is pressed.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var draft = SettingsDraft()
    @State private var loaded = false
    @State private var newCategory = ""
    @State private var problems: [String] = []
    @State private var pendingRemoval: CategoryDraft?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                currencySection
                paySection
                categoriesSection
                fixedItemsSection
            }
            .formStyle(.grouped)

            if !problems.isEmpty {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(problems, id: \.self) { problem in
                            Label(problem, systemImage: "exclamationmark.circle")
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 110)
            }

            Divider()
            HStack {
                Button("Open Data Folder in Finder") { NSWorkspace.shared.open(model.store.directory) }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .help("Save (⌘S)")
            }
            .padding()
        }
        .frame(width: 660, height: 720)
        .onAppear {
            guard !loaded else { return }
            draft = SettingsDraft(settings: model.settings, fixedItems: model.fixedItems)
            loaded = true
        }
        .confirmationDialog(
            "Remove “\(pendingRemoval?.originalName ?? "")”?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { category in
            Button("Remove Category", role: .destructive) { remove(category) }
            Button("Cancel", role: .cancel) {}
        } message: { category in
            let count = model.expenseCount(inCategory: category.originalName ?? "")
            Text("\(count == 1 ? "1 expense uses" : "\(count) expenses use") this category. They will be kept exactly as they are and still count under it, but you won’t be able to pick it for new expenses.")
        }
        // ⌘N still works while Settings is open: the form appears on top of this sheet.
        .sheet(isPresented: Binding(
            get: { model.showingAddExpense && model.showingSettings },
            set: { model.showingAddExpense = $0 }
        )) {
            ExpenseFormView(existing: nil)
        }
    }

    // MARK: Sections

    private var currencySection: some View {
        Section("Currency") {
            TextField("Currency code", text: $draft.currencyCode, prompt: Text("Three-letter code"))
            TextField("Display symbol", text: $draft.currencySymbol, prompt: Text("Shown before amounts"))
        }
    }

    private var paySection: some View {
        Section("Budget and pay") {
            TextField("Monthly spending budget", text: $draft.monthlyBudget, prompt: Text("Amount"))
            TextField("Pay amount", text: $draft.payAmount, prompt: Text("Amount"))
            TextField("Pay frequency (days)", text: $draft.payFrequencyDays, prompt: Text("Days between pay dates"))
            DatePicker("Next pay date", selection: $draft.nextPayDate, displayedComponents: .date)
        }
    }

    private var categoriesSection: some View {
        Section {
            ForEach($draft.categories) { $category in
                HStack {
                    TextField("Category name", text: $category.name, prompt: Text("Category name"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                    Button {
                        requestRemoval(category)
                    } label: {
                        Label("Remove", systemImage: "minus.circle")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Remove category")
                }
            }
            HStack {
                TextField("New category", text: $newCategory, prompt: Text("New category"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addCategory)
                Button("Add", action: addCategory)
                    .disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Categories")
        } footer: {
            Text("Renaming a category also renames it on existing expenses. Removing one leaves existing expenses as they are.")
        }
    }

    private var fixedItemsSection: some View {
        Section {
            if !draft.fixedItems.isEmpty {
                HStack {
                    Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Amount").frame(width: 90, alignment: .leading)
                    Text("Every (days)").frame(width: 90, alignment: .leading)
                    Text("Next due").frame(width: 120, alignment: .leading)
                    Color.clear.frame(width: 20, height: 1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            ForEach($draft.fixedItems) { $item in
                HStack {
                    TextField("Name", text: $item.name, prompt: Text("Name"))
                        .frame(maxWidth: .infinity)
                    TextField("Amount", text: $item.amount, prompt: Text("Amount"))
                        .frame(width: 90)
                    TextField("Frequency in days", text: $item.frequencyDays, prompt: Text("Days"))
                        .frame(width: 90)
                    DatePicker("Next due date", selection: $item.nextDueDate, displayedComponents: .date)
                        .frame(width: 120, alignment: .leading)
                    Button {
                        draft.fixedItems.removeAll { $0.id == item.id }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .frame(width: 20)
                    .help("Delete fixed item")
                }
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
            }
            Button {
                draft.fixedItems.append(FixedItemDraft())
            } label: {
                Label("Add Fixed Item", systemImage: "plus")
            }
        } header: {
            Text("Fixed items")
        } footer: {
            Text("Recurring obligations such as rent, loan payments and subscriptions. Each repeats every given number of days, counted from its next due date.")
        }
    }

    // MARK: Actions

    private func addCategory() {
        let name = newCategory.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        draft.categories.append(CategoryDraft(name: name, originalName: nil))
        newCategory = ""
    }

    /// Warns first if existing expenses use the category.
    private func requestRemoval(_ category: CategoryDraft) {
        if let original = category.originalName, model.expenseCount(inCategory: original) > 0 {
            pendingRemoval = category
        } else {
            remove(category)
        }
    }

    private func remove(_ category: CategoryDraft) {
        draft.categories.removeAll { $0.id == category.id }
    }

    private func save() {
        addCategory() // include a category that was typed but not yet added
        do {
            try model.saveSettings(try draft.validated())
            dismiss()
        } catch let invalid as SettingsDraft.Invalid {
            problems = invalid.messages
        } catch {
            problems = [error.localizedDescription]
        }
    }
}
