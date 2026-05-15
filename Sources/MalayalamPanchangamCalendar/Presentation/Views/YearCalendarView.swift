import SwiftUI

struct YearCalendarView: View {
    @Bindable var viewModel: CalendarViewModel
    var birthNakshatraSet: Set<Nakshatra> = []
    var deathNakshatraSet: Set<Nakshatra> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(1...12, id: \.self) { month in
                MiniMonthView(
                    year: viewModel.selectedYear,
                    month: month,
                    timeZone: viewModel.selectedLocation.timeZone,
                    dayLookup: dayLookup,
                    selectedDayID: viewModel.selectedDayID,
                    isRedDay: { viewModel.isRedDay($0) },
                    birthNakshatraSet: birthNakshatraSet,
                    deathNakshatraSet: deathNakshatraSet
                ) { day in
                    viewModel.select(day: day)
                    viewModel.viewMode = .month
                }
            }
        }
        .padding(24)
    }

    private var dayLookup: [String: PanchangamDay] {
        Dictionary(uniqueKeysWithValues: viewModel.days.map { ($0.isoDateKey, $0) })
    }
}

private struct MiniMonthView: View {
    let year: Int
    let month: Int
    let timeZone: TimeZone
    let dayLookup: [String: PanchangamDay]
    let selectedDayID: PanchangamDay.ID?
    let isRedDay: (PanchangamDay) -> Bool
    var birthNakshatraSet: Set<Nakshatra> = []
    var deathNakshatraSet: Set<Nakshatra> = []
    let onSelect: (PanchangamDay) -> Void

    private static let monthNames = CalendarViewModel.monthNames
    private static let weekdaySymbols = Calendar(identifier: .gregorian).veryShortWeekdaySymbols
    private let cellColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Self.monthNames[month - 1])
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            LazyVGrid(columns: cellColumns, spacing: 2) {
                ForEach(Self.weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(cells, id: \.id) { cell in
                    MiniDayCell(
                        cell: cell,
                        isSelected: cell.day?.id == selectedDayID,
                        isRed: cell.day.map(isRedDay) ?? false,
                        hasBirthdayStar: cell.day.map { birthNakshatraSet.contains($0.mainNakshatra) } ?? false,
                        hasDeathStar: cell.day.map { deathNakshatraSet.contains($0.mainNakshatra) } ?? false
                    ) {
                        if let day = cell.day { onSelect(day) }
                    }
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var cells: [MiniCalendarCell] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        guard
            let firstDate = cal.date(from: DateComponents(year: year, month: month, day: 1)),
            let dayRange = cal.range(of: .day, in: .month, for: firstDate)
        else { return [] }

        let leadingBlanks = cal.component(.weekday, from: firstDate) - 1
        var cells = (0..<leadingBlanks).map { MiniCalendarCell.blank(index: $0) }

        for dayNumber in dayRange {
            var dc = DateComponents(year: year, month: month, day: dayNumber)
            dc.timeZone = timeZone
            guard let date = cal.date(from: dc) else { continue }
            let key = PanchangamFormatters.dateKey(for: date, timeZone: timeZone)
            cells.append(MiniCalendarCell(index: cells.count, dayNumber: dayNumber, day: dayLookup[key]))
        }
        while cells.count % 7 != 0 { cells.append(.blank(index: cells.count)) }
        return cells
    }
}

private struct MiniCalendarCell: Identifiable {
    let id: String
    let index: Int
    let dayNumber: Int?
    let day: PanchangamDay?

    init(index: Int, dayNumber: Int, day: PanchangamDay?) {
        self.id = day?.id ?? "mc-\(index)-\(dayNumber)"
        self.index = index
        self.dayNumber = dayNumber
        self.day = day
    }

    static func blank(index: Int) -> MiniCalendarCell {
        MiniCalendarCell(id: "mb-\(index)", index: index, dayNumber: nil, day: nil)
    }

    private init(id: String, index: Int, dayNumber: Int?, day: PanchangamDay?) {
        self.id = id; self.index = index; self.dayNumber = dayNumber; self.day = day
    }
}

private struct MiniDayCell: View {
    let cell: MiniCalendarCell
    let isSelected: Bool
    let isRed: Bool
    var hasBirthdayStar: Bool = false
    var hasDeathStar: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Text(cell.dayNumber.map(String.init) ?? "")
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(textColor)
                    .frame(maxWidth: .infinity, minHeight: 18)
                    .background(isSelected ? Color.accentColor.opacity(0.8) : Color.clear,
                                in: Circle())

                // Tiny dots for family highlights
                if hasBirthdayStar || hasDeathStar {
                    HStack(spacing: 1) {
                        if hasBirthdayStar {
                            Circle().fill(Color.green).frame(width: 3, height: 3)
                        }
                        if hasDeathStar {
                            Circle().fill(Color.orange).frame(width: 3, height: 3)
                        }
                    }
                    .offset(x: 1, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(cell.dayNumber == nil || cell.day == nil)
        .opacity(cell.dayNumber == nil ? 0 : 1)
    }

    private var textColor: Color {
        if isSelected { return .white }
        if isRed { return Color(red: 0.85, green: 0.1, blue: 0.1) }
        return .primary
    }
}
