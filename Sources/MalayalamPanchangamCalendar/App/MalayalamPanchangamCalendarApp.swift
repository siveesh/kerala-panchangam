import SwiftUI

@main
struct MalayalamPanchangamCalendarApp: App {
    @State private var viewModel = CalendarViewModel()
    @State private var familyViewModel = FamilyViewModel()

    var body: some Scene {
        WindowGroup("Siveesh's Calendar", id: "main") {
            ContentView(viewModel: viewModel, familyViewModel: familyViewModel)
                .frame(minWidth: 1_080, minHeight: 720)
                .task {
                    await viewModel.loadPreferences()
                    if viewModel.days.isEmpty {
                        await viewModel.generate()
                    }
                    await familyViewModel.loadProfiles()
                    // Initial sync after calendar data is ready
                    familyViewModel.days = viewModel.days
                    familyViewModel.duplicateNakshatraPolicy = viewModel.duplicateNakshatraPolicy
                    familyViewModel.duplicateNakshatraThreshold = viewModel.duplicateNakshatraThreshold
                    familyViewModel.ayanamsaSelection = viewModel.ayanamsaSelection
                    familyViewModel.refreshHighlights()
                }
        }
        .defaultSize(width: 1_200, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Regenerate Calendar") {
                    Task { await viewModel.generate(forceRefresh: true) }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
