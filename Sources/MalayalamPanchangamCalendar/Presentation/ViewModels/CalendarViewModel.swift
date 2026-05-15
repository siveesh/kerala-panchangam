import Foundation
import Observation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
@Observable
final class CalendarViewModel {
    var selectedYear: Int
    var selectedLocation: GeoLocation
    var calculationMode: CalculationMode
    var languagePreference: LanguagePreference
    var validationStrictness: ValidationStrictness
    var ayanamsaSelection: AyanamsaSelection
    var notificationsEnabled: Bool
    var calendarIntegrationEnabled: Bool
    var uses24HourTime: Bool
    var duplicateNakshatraPolicy: DuplicateNakshatraPolicy
    var duplicateNakshatraThreshold: DuplicateNakshatraThreshold
    var shraddhamObservanceMode: ShraddhamObservanceMode
    var selectedSection: AppSection = .calendar
    var viewMode: CalendarViewMode = .month
    var days: [PanchangamDay] = []
    var selectedDayID: PanchangamDay.ID?
    var focusedMonth: Int
    var searchText = ""
    var isGenerating = false
    var isLoadingPreferences = false
    var errorMessage: String?

    private let generator: YearGenerationService
    private let preferencesStore: AppPreferencesStoring
    private let widgetSnapshotStore: WidgetSnapshotStore

    init(
        selectedYear: Int = Calendar(identifier: .gregorian).component(.year, from: .now),
        selectedLocation: GeoLocation = .thrissur,
        calculationMode: CalculationMode = .keralaTraditional,
        languagePreference: LanguagePreference = .bilingual,
        validationStrictness: ValidationStrictness = .standard,
        ayanamsaSelection: AyanamsaSelection = .lahiri,
        notificationsEnabled: Bool = false,
        calendarIntegrationEnabled: Bool = false,
        uses24HourTime: Bool = false,
        duplicateNakshatraPolicy: DuplicateNakshatraPolicy = .preferSecondUnlessShort,
        duplicateNakshatraThreshold: DuplicateNakshatraThreshold = .default,
        shraddhamObservanceMode: ShraddhamObservanceMode = .nakshatraOnly,
        generator: YearGenerationService = YearGenerationService(),
        preferencesStore: AppPreferencesStoring = UserDefaultsAppPreferencesStore(),
        widgetSnapshotStore: WidgetSnapshotStore = WidgetSnapshotStore()
    ) {
        self.selectedYear = selectedYear
        self.selectedLocation = selectedLocation
        self.calculationMode = calculationMode
        self.languagePreference = languagePreference
        self.validationStrictness = validationStrictness
        self.ayanamsaSelection = ayanamsaSelection
        self.notificationsEnabled = notificationsEnabled
        self.calendarIntegrationEnabled = calendarIntegrationEnabled
        self.uses24HourTime = uses24HourTime
        self.duplicateNakshatraPolicy = duplicateNakshatraPolicy
        self.duplicateNakshatraThreshold = duplicateNakshatraThreshold
        self.shraddhamObservanceMode = shraddhamObservanceMode
        self.focusedMonth = Calendar(identifier: .gregorian).component(.month, from: .now)
        self.generator = generator
        self.preferencesStore = preferencesStore
        self.widgetSnapshotStore = widgetSnapshotStore
    }

    var filteredDays: [PanchangamDay] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return days }
        return days.filter { day in
            day.isoDateKey.localizedCaseInsensitiveContains(searchText)
                || day.mainNakshatra.englishName.localizedCaseInsensitiveContains(searchText)
                || day.malayalamMonth.englishName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var selectedDay: PanchangamDay? {
        if let selectedDayID, let day = days.first(where: { $0.id == selectedDayID }) {
            return day
        }
        return days.first
    }

    var focusedMonthDays: [PanchangamDay] {
        days.filter { monthFromKey($0.isoDateKey) == focusedMonth }
    }

    // Hardcoded English — Calendar.monthSymbols is locale-dependent and returns "M06" style
    // strings on Malayalam/non-Latin locales.
    static let monthNames = ["January", "February", "March", "April", "May", "June",
                              "July", "August", "September", "October", "November", "December"]

    var focusedMonthName: String {
        Self.monthNames[max(0, min(focusedMonth - 1, 11))]
    }

    // e.g. "1201 Medam & Edavam" — the Malayalam months that overlap the focused Gregorian month.
    var focusedMonthMalayalamSubtitle: String {
        let monthDays = focusedMonthDays
        guard !monthDays.isEmpty else { return "" }
        var seenMonths = Set<Int>()
        var result: [(kollavarshamYear: Int, month: MalayalamMonth)] = []
        for day in monthDays {
            if seenMonths.insert(day.malayalamMonth.rawValue).inserted {
                result.append((day.kollavarshamYear, day.malayalamMonth))
            }
        }
        guard !result.isEmpty else { return "" }
        let kollYear = result.first!.kollavarshamYear
        let names = result.map { $0.month.englishName }.joined(separator: " & ")
        return "\(kollYear) \(names)"
    }

    // Human-readable period label for the currently active navigation state.
    var periodTitle: String {
        switch viewMode {
        case .year:
            return selectedYear.formatted(.number.grouping(.never))
        case .month:
            return "\(focusedMonthName) \(selectedYear.formatted(.number.grouping(.never)))"
        case .week:
            let wDays = weekDays
            guard let first = wDays.first, let last = wDays.last else {
                return "\(focusedMonthName) \(selectedYear.formatted(.number.grouping(.never)))"
            }
            let cal = gregorianCalendar()
            let sm = cal.component(.month, from: first.date)
            let em = cal.component(.month, from: last.date)
            let sd = cal.component(.day, from: first.date)
            let ed = cal.component(.day, from: last.date)
            if sm == em {
                return "\(Self.monthNames[sm - 1]) \(sd)–\(ed), \(selectedYear.formatted(.number.grouping(.never)))"
            } else {
                return "\(Self.monthNames[sm - 1]) \(sd) – \(Self.monthNames[em - 1]) \(ed)"
            }
        case .day:
            guard let day = selectedDay else {
                return "\(focusedMonthName) \(selectedYear.formatted(.number.grouping(.never)))"
            }
            let cal = gregorianCalendar()
            let d = cal.component(.day, from: day.date)
            let m = cal.component(.month, from: day.date)
            return "\(day.weekday), \(Self.monthNames[m - 1]) \(d), \(selectedYear.formatted(.number.grouping(.never)))"
        }
    }

    // Subtitle for the period navigation bar (Malayalam calendar info).
    var periodSubtitle: String {
        switch viewMode {
        case .year:
            return ""
        case .month:
            return focusedMonthMalayalamSubtitle
        case .week:
            let wDays = weekDays
            guard !wDays.isEmpty else { return "" }
            var seenMonths = Set<Int>()
            var names: [String] = []
            for d in wDays {
                if seenMonths.insert(d.malayalamMonth.rawValue).inserted {
                    names.append(d.malayalamMonth.englishName)
                }
            }
            let kollYear = wDays.first!.kollavarshamYear
            return "\(kollYear) \(names.joined(separator: " & "))"
        case .day:
            guard let day = selectedDay else { return "" }
            return "\(day.malayalamMonth.englishName) \(day.malayalamDay), \(day.kollavarshamYear) • \(day.mainNakshatra.englishName)"
        }
    }

    // The 7 days of the week that contains the currently selected day (Sunday-first).
    var weekDays: [PanchangamDay] {
        guard let selected = selectedDay else { return Array(days.prefix(7)) }
        let cal = gregorianCalendar()
        let weekdayOffset = cal.component(.weekday, from: selected.date) - 1 // 0=Sun
        guard let weekStart = cal.date(byAdding: .day, value: -weekdayOffset, to: selected.date) else { return [] }
        let weekKeys: [String] = (0..<7).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return PanchangamFormatters.dateKey(for: d, timeZone: selectedLocation.timeZone)
        }
        let lookup = Dictionary(uniqueKeysWithValues: days.map { ($0.isoDateKey, $0) })
        return weekKeys.compactMap { lookup[$0] }
    }

    // True if the day falls on a Sunday or is a Kerala public holiday.
    func isRedDay(_ day: PanchangamDay) -> Bool {
        let cal = gregorianCalendar()
        let weekday = cal.component(.weekday, from: day.date)
        if weekday == 1 { return true }
        return KeralaHolidays.isHoliday(isoDateKey: day.isoDateKey, year: selectedYear)
    }

    func generate(forceRefresh: Bool = false) async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            let generated = try await generator.generateYear(
                year: selectedYear,
                location: selectedLocation,
                mode: calculationMode,
                forceRefresh: forceRefresh
            )
            days = generated

            // Prefer today when generating the current year — gives immediate context on first open.
            let currentYear = Calendar(identifier: .gregorian).component(.year, from: .now)
            let todayKey = PanchangamFormatters.dateKey(for: .now, timeZone: selectedLocation.timeZone)
            if selectedYear == currentYear, let todayDay = generated.first(where: { $0.isoDateKey == todayKey }) {
                selectedDayID = todayDay.id
                focusedMonth = gregorianMonth(for: todayDay.date)
            } else if selectedDayID == nil || !generated.contains(where: { $0.id == selectedDayID }) {
                selectedDayID = generated.first(where: { gregorianMonth(for: $0.date) == focusedMonth })?.id ?? generated.first?.id
            }
            publishSelectedDaySnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPreferences() async {
        isLoadingPreferences = true
        defer { isLoadingPreferences = false }
        let preferences = await preferencesStore.load()
        selectedLocation = preferences.preferredLocation
        calculationMode = preferences.calculationMode
        languagePreference = preferences.languagePreference
        validationStrictness = preferences.validationStrictness
        ayanamsaSelection = preferences.ayanamsaSelection
        notificationsEnabled = preferences.notificationsEnabled
        calendarIntegrationEnabled = preferences.calendarIntegrationEnabled
        uses24HourTime = preferences.uses24HourTime
        duplicateNakshatraPolicy = preferences.duplicateNakshatraPolicy
        duplicateNakshatraThreshold = preferences.duplicateNakshatraThreshold
        shraddhamObservanceMode = preferences.shraddhamObservanceMode
    }

    func savePreferences() {
        let preferences = AppPreferences(
            preferredLocation: selectedLocation,
            calculationMode: calculationMode,
            languagePreference: languagePreference,
            validationStrictness: validationStrictness,
            ayanamsaSelection: ayanamsaSelection,
            notificationsEnabled: notificationsEnabled,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            uses24HourTime: uses24HourTime,
            duplicateNakshatraPolicy: duplicateNakshatraPolicy,
            duplicateNakshatraThreshold: duplicateNakshatraThreshold,
            shraddhamObservanceMode: shraddhamObservanceMode
        )
        Task {
            await preferencesStore.save(preferences)
        }
    }

    func select(day: PanchangamDay) {
        selectedDayID = day.id
        focusedMonth = gregorianMonth(for: day.date)
        publishSelectedDaySnapshot()
    }

    func moveFocusedMonth(by offset: Int) {
        let next = focusedMonth + offset
        if next < 1 {
            focusedMonth = 12
            selectedYear -= 1
        } else if next > 12 {
            focusedMonth = 1
            selectedYear += 1
        } else {
            focusedMonth = next
        }
        selectedDayID = days.first(where: { gregorianMonth(for: $0.date) == focusedMonth })?.id
    }

    func navigatePrevious() {
        switch viewMode {
        case .year:
            selectedYear -= 1
        case .month:
            moveFocusedMonth(by: -1)
        case .week:
            moveSelectedDays(by: -7)
        case .day:
            moveSelectedDays(by: -1)
        }
    }

    func navigateNext() {
        switch viewMode {
        case .year:
            selectedYear += 1
        case .month:
            moveFocusedMonth(by: 1)
        case .week:
            moveSelectedDays(by: 7)
        case .day:
            moveSelectedDays(by: 1)
        }
    }

    private func moveSelectedDays(by count: Int) {
        guard let current = selectedDay else { return }
        let cal = gregorianCalendar()
        guard let target = cal.date(byAdding: .day, value: count, to: current.date) else { return }
        let targetKey = PanchangamFormatters.dateKey(for: target, timeZone: selectedLocation.timeZone)
        let lookup = Dictionary(uniqueKeysWithValues: days.map { ($0.isoDateKey, $0) })
        if let day = lookup[targetKey] {
            select(day: day)
        } else {
            let newYear = cal.component(.year, from: target)
            let newMonth = cal.component(.month, from: target)
            if newYear != selectedYear {
                selectedYear = newYear
            }
            focusedMonth = newMonth
        }
    }

    private func gregorianCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = selectedLocation.timeZone
        return cal
    }

    private func gregorianMonth(for date: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = selectedLocation.timeZone
        return cal.component(.month, from: date)
    }

    // Fast variant used in hot filter paths — parses the stored "yyyy-MM-dd" key directly.
    private func monthFromKey(_ key: String) -> Int? {
        guard key.count == 10 else { return nil }
        return Int(key[key.index(key.startIndex, offsetBy: 5)..<key.index(key.startIndex, offsetBy: 7)])
    }

    private func publishSelectedDaySnapshot() {
        guard let selectedDay else { return }
        let snapshot = PanchangamDaySnapshot(day: selectedDay, languagePreference: languagePreference)
        Task {
            if (try? await widgetSnapshotStore.saveSnapshot(snapshot)) != nil {
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadTimelines(ofKind: "MalayalamPanchangamDayWidget")
                #endif
            }
        }
    }
}
