import SwiftUI

struct WeekCalendarView: View {
    @Bindable var viewModel: CalendarViewModel
    var birthNakshatraSet: Set<Nakshatra> = []
    var deathNakshatraSet: Set<Nakshatra> = []
    var familyEventsByDate: [String: [FamilyDayEvent]] = [:]

    private static let shortDayNames = Calendar(identifier: .gregorian).shortWeekdaySymbols

    var body: some View {
        ScrollView(.vertical) {
            if viewModel.weekDays.isEmpty {
                ContentUnavailableView("No Data", systemImage: "calendar",
                    description: Text("Generate a calendar to see the week view."))
                    .padding(40)
            } else {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(viewModel.weekDays) { day in
                        WeekDayColumn(
                            day: day,
                            isSelected: day.id == viewModel.selectedDayID,
                            isRed: viewModel.isRedDay(day),
                            languagePreference: viewModel.languagePreference,
                            hasBirthdayStar: birthNakshatraSet.contains(day.mainNakshatra),
                            hasDeathStar: deathNakshatraSet.contains(day.mainNakshatra),
                            familyEvents: familyEventsByDate[day.isoDateKey] ?? [],
                            onSelect: { viewModel.select(day: day) },
                            onShowFullDay: { viewModel.viewMode = .day }
                        )
                    }
                }
            }
        }
    }
}

private struct WeekDayColumn: View {
    let day: PanchangamDay
    let isSelected: Bool
    let isRed: Bool
    let languagePreference: LanguagePreference
    var hasBirthdayStar: Bool = false
    var hasDeathStar: Bool = false
    var familyEvents: [FamilyDayEvent] = []
    let onSelect: () -> Void
    var onShowFullDay: () -> Void = {}

    @State private var showingDetail = false

    private static let shortDayNames = Calendar(identifier: .gregorian).shortWeekdaySymbols

    var body: some View {
        Button(action: {
            onSelect()
            showingDetail = true
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Day header
                VStack(spacing: 3) {
                    Text(dayOfWeek)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isRed ? redColor : .secondary)
                    Text(dayNumber)
                        .font(.title2.weight(isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? Color.accentColor : (isRed ? redColor : .primary))
                    // Family star dots
                    if hasBirthdayStar || hasDeathStar {
                        HStack(spacing: 3) {
                            if hasBirthdayStar {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                    .help("Birthday star")
                            }
                            if hasDeathStar {
                                Circle().fill(Color.orange).frame(width: 6, height: 6)
                                    .help("Death star (Śrāddham)")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)

                Divider()

                // Panchangam data
                VStack(alignment: .leading, spacing: 10) {
                    infoRow(label: "\(day.malayalamMonth.englishName) \(day.malayalamDay)",
                            icon: "calendar")
                    infoRow(label: star(day.mainNakshatra), icon: "sparkle")
                    // Family event labels in yellow
                    if !familyEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(familyEvents) { event in
                                Text(event.label)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.yellow)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(Color.secondary.opacity(0.15)),
            alignment: .trailing
        )
        .background(isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
        .popover(isPresented: $showingDetail, arrowEdge: .bottom) {
            DayQuickLookView(
                day: day,
                languagePreference: languagePreference,
                isPresented: $showingDetail,
                onShowFullDay: {
                    showingDetail = false
                    onShowFullDay()
                }
            )
        }
    }

    private var dayOfWeek: String {
        let cal = Calendar(identifier: .gregorian)
        let weekday = cal.component(.weekday, from: day.date) - 1
        return Self.shortDayNames[weekday]
    }

    private var dayNumber: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = day.location.timeZone
        return "\(cal.component(.day, from: day.date))"
    }

    private var redColor: Color { Color(red: 0.85, green: 0.1, blue: 0.1) }

    private func star(_ n: Nakshatra) -> String {
        switch languagePreference {
        case .english: n.englishName
        case .malayalam: n.malayalamName
        case .bilingual: n.englishName
        }
    }

    @ViewBuilder
    private func infoRow(label: String, icon: String) -> some View {
        Label(label, systemImage: icon)
            .font(.caption2)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }
}
