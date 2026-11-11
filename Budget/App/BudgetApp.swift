import SwiftUI

@main
struct BudgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel(store: DataStore(directory: DataStore.defaultDirectory()))

    /// When the app is only hosting unit tests it must not open or create the real data folder.
    private var isHostingTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return ["XCTestConfigurationFilePath", "XCTestBundlePath", "XCTestSessionIdentifier"]
            .contains { environment[$0] != nil }
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? ProcessInfo.processInfo.processName
    }

    var body: some Scene {
        Window(appName, id: "main") {
            if isHostingTests {
                Text("Running unit tests…")
                    .frame(width: 320, height: 120)
            } else {
                ContentView()
                    .environment(model)
            }
        }
        .defaultSize(width: 920, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Expense…") { model.requestAddExpense() }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(!model.canAddExpense)
                Button("Reload Data") { model.reloadIfIdle() }
                    .keyboardShortcut("r", modifiers: .command)
            }
            CommandGroup(replacing: .sidebar) {} // the app has no sidebar to toggle
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { model.showingSettings = true }
                    .keyboardShortcut(",", modifiers: .command)
                    .disabled(!model.hasLoaded || model.showingSettings)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
