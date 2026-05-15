import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: CalendarViewModel
    @Bindable var familyViewModel: FamilyViewModel
    @State private var showsLocationSelection = false

    var body: some View {
        // No NavigationStack — on macOS, NavigationStack treats every .navigationTitle
        // update as a nav-level change, causing DayDetailView to overlay the calendar.
        // Toolbar and .searchable both work on any view in the window hierarchy.
        VStack(spacing: 0) {
            switch viewModel.selectedSection {
            case .calendar:
                calendarContent
            case .reminders:
                ScrollView {
                    RemindersView(
                    days: viewModel.days,
                    duplicateNakshatraPolicy: $viewModel.duplicateNakshatraPolicy,
                    duplicateNakshatraThreshold: $viewModel.duplicateNakshatraThreshold
                )
                        .padding(24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .family:
                FamilyView(viewModel: familyViewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .searchable(text: $viewModel.searchText, prompt: "Search dates, months, stars")
        .toolbar { toolbarContent }
        .onChange(of: viewModel.selectedYear) { _, _ in
            Task { await viewModel.generate() }
        }
        .onChange(of: viewModel.selectedLocation) { _, _ in
            viewModel.savePreferences()
            Task { await viewModel.generate() }
        }
        .onChange(of: viewModel.calculationMode) { _, _ in
            viewModel.savePreferences()
            Task { await viewModel.generate() }
        }
        // Sync calendar data to FamilyViewModel whenever it changes
        .onChange(of: viewModel.days) { _, newDays in
            familyViewModel.days = newDays
            familyViewModel.duplicateNakshatraPolicy = viewModel.duplicateNakshatraPolicy
            familyViewModel.duplicateNakshatraThreshold = viewModel.duplicateNakshatraThreshold
            familyViewModel.ayanamsaSelection = viewModel.ayanamsaSelection
            familyViewModel.shraddhamObservanceMode = viewModel.shraddhamObservanceMode
            familyViewModel.refreshHighlights()
        }
        .onChange(of: viewModel.ayanamsaSelection) { _, new in
            familyViewModel.ayanamsaSelection = new
        }
        .onChange(of: viewModel.shraddhamObservanceMode) { _, new in
            viewModel.savePreferences()
            familyViewModel.shraddhamObservanceMode = new
            familyViewModel.refreshHighlights()
        }
        .sheet(isPresented: $showsLocationSelection) {
            LocationSelectionView(selectedLocation: $viewModel.selectedLocation)
        }
    }

    // MARK: - Calendar layout

    private var calendarContent: some View {
        VStack(spacing: 0) {
            periodNavigationBar
            Divider()
            calendarBody
        }
    }

    @ViewBuilder
    private var calendarBody: some View {
        switch viewModel.viewMode {
        case .year:
            ScrollView {
                YearCalendarView(
                    viewModel: viewModel,
                    birthNakshatraSet: familyViewModel.birthNakshatraSet,
                    deathNakshatraSet: familyViewModel.deathNakshatraSet
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .month:
            ScrollView {
                MonthCalendarView(
                    viewModel: viewModel,
                    birthNakshatraSet: familyViewModel.birthNakshatraSet,
                    deathNakshatraSet: familyViewModel.deathNakshatraSet,
                    familyEventsByDate: familyViewModel.familyEventsByDate
                )
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .week:
            WeekCalendarView(
                viewModel: viewModel,
                birthNakshatraSet: familyViewModel.birthNakshatraSet,
                deathNakshatraSet: familyViewModel.deathNakshatraSet,
                familyEventsByDate: familyViewModel.familyEventsByDate
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .day:
            if let day = viewModel.selectedDay {
                DayDetailView(
                    day: day,
                    yearDays: viewModel.days,
                    languagePreference: viewModel.languagePreference,
                    familyEvents: familyViewModel.familyEventsByDate[day.isoDateKey] ?? []
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("No Day Selected", systemImage: "calendar",
                    description: Text("Generate a calendar and select a day."))
            }
        }
    }

    // MARK: - Period navigation bar

    private var periodNavigationBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.navigatePrevious()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
            .help("Previous \(viewModel.viewMode.title.lowercased())")

            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.periodTitle)
                    .font(.title3.weight(.semibold))
                if !viewModel.periodSubtitle.isEmpty {
                    Text(viewModel.periodSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Picker("View mode", selection: $viewModel.viewMode) {
                ForEach(CalendarViewMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            Button {
                viewModel.navigateNext()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
            .help("Next \(viewModel.viewMode.title.lowercased())")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Picker("Section", selection: $viewModel.selectedSection) {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            if viewModel.isGenerating {
                ProgressView()
                    .controlSize(.small)
                    .help("Generating calendar…")
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            YearStepper(year: $viewModel.selectedYear)

            Menu {
                Section("Kerala Districts") {
                    ForEach(GeoLocation.keralaDistricts) { loc in
                        Button(loc.name) { viewModel.selectedLocation = loc }
                    }
                }
                Section("Major Cities") {
                    ForEach(GeoLocation.majorIndianCities) { loc in
                        Button(loc.name) { viewModel.selectedLocation = loc }
                    }
                }
                Section("International") {
                    ForEach(GeoLocation.internationalCities) { loc in
                        Button(loc.name) { viewModel.selectedLocation = loc }
                    }
                }
                Divider()
                Button("More / Search / Map…") { showsLocationSelection = true }
            } label: {
                Label(viewModel.selectedLocation.name, systemImage: "location.fill")
            }
            .help("Choose location or open full picker")

            Picker("Mode", selection: $viewModel.calculationMode) {
                ForEach(CalculationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .frame(width: 175)
            .help("Calculation mode")

            Button {
                Task { await viewModel.generate(forceRefresh: true) }
            } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
            }
            .help("Force regenerate calendar data")
        }
    }
}

// MARK: - Day Quick Look (popover)

struct DayQuickLookView: View {
    let day: PanchangamDay
    let languagePreference: LanguagePreference
    @Binding var isPresented: Bool
    var onShowFullDay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.headline)
                    Text(malayalamDateLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Key metrics (4 items)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Label("Star", systemImage: "sparkle")
                        .foregroundStyle(.secondary).font(.caption)
                    Text(starName(day.mainNakshatra))
                        .font(.caption.weight(.medium))
                }
                GridRow {
                    Label("Tithi", systemImage: "moon.circle")
                        .foregroundStyle(.secondary).font(.caption)
                    Text("\(day.tithi.paksha) \(day.tithi.englishName)")
                        .font(.caption.weight(.medium))
                }
                GridRow {
                    Label("Sunrise", systemImage: "sunrise.fill")
                        .foregroundStyle(.secondary).font(.caption)
                    Text(PanchangamFormatters.time(day.sunrise, timeZone: day.location.timeZone))
                        .font(.caption.weight(.medium))
                }
                GridRow {
                    Label("Rahu", systemImage: "clock.badge.exclamationmark")
                        .foregroundStyle(.secondary).font(.caption)
                    Text(period(day.rahuKalam))
                        .font(.caption.weight(.medium))
                }
            }

            Button("Full Day View →") { onShowFullDay() }
                .font(.caption)
                .buttonStyle(.link)
        }
        .padding(16)
        .frame(width: 280)
    }

    private var malayalamDateLabel: String {
        let m = languagePreference == .malayalam ? day.malayalamMonth.malayalamName : day.malayalamMonth.englishName
        return "\(m) \(day.malayalamDay) · KE \(day.kollavarshamYear)"
    }

    private func starName(_ n: Nakshatra) -> String {
        switch languagePreference {
        case .english:   return n.englishName
        case .malayalam: return n.malayalamName
        case .bilingual: return "\(n.englishName) / \(n.malayalamName)"
        }
    }

    private func period(_ p: TimePeriod) -> String {
        "\(PanchangamFormatters.time(p.start, timeZone: day.location.timeZone)) – \(PanchangamFormatters.time(p.end, timeZone: day.location.timeZone))"
    }
}

// MARK: - Year stepper

private struct YearStepper: View {
    @Binding var year: Int

    var body: some View {
        Stepper(value: $year, in: 1900...2200) {
            Text(year.formatted(.number.grouping(.never)))
                .monospacedDigit()
                .frame(width: 54, alignment: .trailing)
        }
        .help("Gregorian year")
    }
}
