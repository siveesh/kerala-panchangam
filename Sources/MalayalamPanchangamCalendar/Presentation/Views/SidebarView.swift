import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: CalendarViewModel

    var body: some View {
        List(selection: $viewModel.selectedDayID) {
            Section {
                ForEach(viewModel.filteredDays) { day in
                    SidebarDayRow(day: day)
                        .tag(day.id)
                }
            } header: {
                HStack {
                    Text(viewModel.selectedLocation.name)
                    if viewModel.isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Panchangam")
        .overlay {
            if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView("Generation Failed", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            }
        }
    }
}

private struct SidebarDayRow: View {
    let day: PanchangamDay

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(day.isoDateKey)
                    .lineLimit(1)
                Text("\(day.malayalamMonth.englishName) \(day.malayalamDay) • \(day.mainNakshatra.englishName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
