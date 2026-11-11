import Foundation

/// Reads and writes the three CSV files in the data folder.
struct DataStore {
    enum File: String, CaseIterable {
        case settings = "settings.csv"
        case fixedItems = "fixed_items.csv"
        case expenses = "expenses.csv"
    }

    static let folderName = "Budget"
    /// Set this environment variable to keep data somewhere other than ~/Documents/Budget
    /// (useful for trying the app without touching real data).
    static let directoryOverrideVariable = "BUDGET_DATA_DIR"

    let directory: URL

    /// ~/Documents/Budget for whoever is running the app, unless overridden.
    static func defaultDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let override = environment[directoryOverrideVariable], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        return documents.appendingPathComponent(folderName, isDirectory: true)
    }

    func url(_ file: File) -> URL { directory.appendingPathComponent(file.rawValue) }

    /// Creates the folder and any missing file, with headers and empty values only.
    /// Existing files are never touched.
    func ensureFilesExist() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let blanks: [(File, String)] = [
            (.settings, SettingsCodec.encode(Settings())),
            (.fixedItems, FixedItemCodec.encode([])),
            (.expenses, ExpenseCodec.encode([])),
        ]
        for (file, text) in blanks where !fm.fileExists(atPath: url(file).path) {
            try write(text, to: file)
        }
    }

    func read(_ file: File) throws -> String {
        try String(contentsOf: url(file), encoding: .utf8)
    }

    /// Writes to a temporary file in the same folder, then swaps it into place,
    /// so a crash mid-write can never leave a half-written data file.
    func write(_ text: String, to file: File) throws {
        let fm = FileManager.default
        let destination = url(file)
        let temporary = directory.appendingPathComponent(".\(file.rawValue).\(UUID().uuidString).tmp")
        try Data(text.utf8).write(to: temporary)
        do {
            if fm.fileExists(atPath: destination.path) {
                _ = try fm.replaceItemAt(destination, withItemAt: temporary)
            } else {
                try fm.moveItem(at: temporary, to: destination)
            }
        } catch {
            try? fm.removeItem(at: temporary)
            throw error
        }
    }
}
