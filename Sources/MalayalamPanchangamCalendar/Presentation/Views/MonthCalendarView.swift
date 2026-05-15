import SwiftUI

struct MonthCalendarView: View {
    @Bindable var viewModel: CalendarViewModel
    var birthNakshatraSet: Set<Nakshatra> = []
    var deathNakshatraSet: Set<Nakshatra> = []
    var familyEventsByDate: [String: [FamilyDayEvent]] = [:]

    private let columns = Array(repeating: GridItem(.flexible(minimum: 80), spacing: 6), count: 7)
    private static let weekdaySymbols = Calendar(identifier: .gregorian).shortWeekdaySymbols

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(monthCells) { cell in
                    MonthDayCell(
                        cell: cell,
                        isSelected: cell.day?.id == viewModel.selectedDayID,
                        isRed: cell.day.map { viewModel.isRedDay($0) } ?? false,
                        languagePreference: viewModel.languagePreference,
                        hasBirthdayStar: cell.day.map { birthNakshatraSet.contains($0.mainNakshatra) } ?? false,
                        hasDeathStar: cell.day.map { deathNakshatraSet.contains($0.mainNakshatra) } ?? false,
                        familyEvents: cell.day.flatMap { familyEventsByDate[$0.isoDateKey] } ?? [],
                        action: {
                            if let day = cell.day {
                                viewModel.select(day: day)
                            }
                        },
                        onShowFullDay: {
                            viewModel.viewMode = .day
                        }
                    )
                }
            }
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(Self.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(index == 0 ? Color(red: 0.85, green: 0.1, blue: 0.1) : Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var monthCells: [MonthCalendarCell] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = viewModel.selectedLocation.timeZone
        guard
            let firstDate = calendar.date(from: DateComponents(
                timeZone: viewModel.selectedLocation.timeZone,
                year: viewModel.selectedYear,
                month: viewModel.focusedMonth,
                day: 1)),
            let dayRange = calendar.range(of: .day, in: .month, for: firstDate)
        else {
            return []
        }

        // O(n) index: map day-number → PanchangamDay for the focused month.
        let focusedMonth = viewModel.focusedMonth
        var dayByNumber: [Int: PanchangamDay] = Dictionary(minimumCapacity: 31)
        for panchangamDay in viewModel.days {
            let key = panchangamDay.isoDateKey
            guard key.count == 10,
                  let m = Int(key[key.index(key.startIndex, offsetBy: 5)..<key.index(key.startIndex, offsetBy: 7)]),
                  m == focusedMonth,
                  let d = Int(key[key.index(key.startIndex, offsetBy: 8)...])
            else { continue }
            dayByNumber[d] = panchangamDay
        }

        let leadingBlanks = calendar.component(.weekday, from: firstDate) - 1
        var cells = (0..<leadingBlanks).map { MonthCalendarCell.placeholder(index: $0) }
        for dayNumber in dayRange {
            cells.append(MonthCalendarCell(index: cells.count, dayNumber: dayNumber, day: dayByNumber[dayNumber]))
        }
        while cells.count % 7 != 0 {
            cells.append(.placeholder(index: cells.count))
        }
        return cells
    }
}

struct MonthCalendarCell: Identifiable {
    let id: String
    let index: Int
    let dayNumber: Int?
    let day: PanchangamDay?

    init(index: Int, dayNumber: Int, day: PanchangamDay?) {
        self.id = day?.id ?? "day-\(index)-\(dayNumber)"
        self.index = index
        self.dayNumber = dayNumber
        self.day = day
    }

    static func placeholder(index: Int) -> MonthCalendarCell {
        MonthCalendarCell(id: "placeholder-\(index)", index: index, dayNumber: nil, day: nil)
    }

    private init(id: String, index: Int, dayNumber: Int?, day: PanchangamDay?) {
        self.id = id
        self.index = index
        self.dayNumber = dayNumber
        self.day = day
    }
}

private struct MonthDayCell: View {
    let cell: MonthCalendarCell
    let isSelected: Bool
    let isRed: Bool
    let languagePreference: LanguagePreference
    var hasBirthdayStar: Bool = false
    var hasDeathStar: Bool = false
    var familyEvents: [FamilyDayEvent] = []
    let action: () -> Void
    var onShowFullDay: () -> Void = {}

    @State private var showingDetail = false

    // Fixed red: used for Sundays and Kerala holidays regardless of system appearance.
    private static let holidayRed = Color(red: 0.85, green: 0.1, blue: 0.1)

    var body: some View {
        Button(action: {
            action()
            if cell.day != nil { showingDetail = true }
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(cell.dayNumber.map(String.init) ?? "")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(isSelected ? Color.white : (isRed ? Self.holidayRed : Color.primary))
                    // Family star highlights
                    if hasBirthdayStar || hasDeathStar {
                        HStack(spacing: 2) {
                            if hasBirthdayStar {
                                Circle()
                                    .fill(isSelected ? Color.white : Color.green)
                                    .frame(width: 5, height: 5)
                                    .help("Birthday star")
                            }
                            if hasDeathStar {
                                Circle()
                                    .fill(isSelected ? Color.white.opacity(0.7) : Color.orange)
                                    .frame(width: 5, height: 5)
                                    .help("Death star (Śrāddham)")
                            }
                        }
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                    }
                }

                if let day = cell.day {
                    Text("\(month(day.malayalamMonth)) \(day.malayalamDay)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.secondary)
                        .lineLimit(1)
                    Text(star(day.mainNakshatra))
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.primary.opacity(0.7))
                        .lineLimit(1)
                    // Family event labels (birthday ★ / Śrāddham †) in yellow
                    ForEach(familyEvents.prefix(2)) { event in
                        Text(event.label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(isSelected ? Color.yellow.opacity(0.9) : Color.yellow)
                            .lineLimit(1)
                    }
                } else {
                    Spacer(minLength: 30)
                }
            }
            .padding(10)
            .frame(minHeight: 96, alignment: .topLeading)
            .frame(maxWidth: .infinity)
            .background(cellBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : (isRed && cell.day != nil ? Self.holidayRed.opacity(0.35) : Color.secondary.opacity(0.18)),
                            lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(cell.day == nil)
        .opacity(cell.day == nil ? 0.35 : 1)
        .popover(isPresented: $showingDetail, arrowEdge: .bottom) {
            if let day = cell.day {
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
    }

    private var cellBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.85))
        }
        if isRed && cell.day != nil {
            return AnyShapeStyle(Self.holidayRed.opacity(0.07))
        }
        return AnyShapeStyle(.regularMaterial)
    }

    private func month(_ month: MalayalamMonth) -> String {
        switch languagePreference {
        case .english: month.englishName
        case .malayalam: month.malayalamName
        case .bilingual: month.englishName
        }
    }

    private func star(_ nakshatra: Nakshatra) -> String {
        switch languagePreference {
        case .english: nakshatra.englishName
        case .malayalam: nakshatra.malayalamName
        case .bilingual: nakshatra.englishName
        }
    }

}
