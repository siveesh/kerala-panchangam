import SwiftUI

struct DayDetailView: View {
    let day: PanchangamDay
    let yearDays: [PanchangamDay]
    let languagePreference: LanguagePreference
    var familyEvents: [FamilyDayEvent] = []

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            leftColumn
            Divider()
            rightColumn
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Left column  (header + metrics + family events + Panchangam Details)

    private var leftColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                metricsGrid
                if !familyEvents.isEmpty {
                    familyEventsSection
                }
                sectionLabel("Panchangam Details", icon: "list.bullet.rectangle")
                PanchangamDetailScreen(day: day, languagePreference: languagePreference)
            }
            .padding(20)
        }
        .frame(minWidth: 280, maxWidth: .infinity)
    }

    // MARK: - Right column  (Grahanila — always expanded)

    private var rightColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Grahanila · ഗ്രഹനില", icon: "moon.stars.fill")
                GrahanilaChartView(
                    day: day,
                    languagePreference: languagePreference,
                    ayanamsaSelection: .lahiri
                )
            }
            .padding(16)
        }
        .frame(minWidth: 280, maxWidth: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(headerTitle)
                .font(.title2.weight(.semibold))
            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    /// "Tuesday  2026-06-02"  — no comma between weekday and date.
    private var headerTitle: String {
        "\(day.weekday)  \(day.isoDateKey)"
    }

    /// "Edavam 19 · Kollavarsham 1201"  — no commas, no thousands separator.
    private var headerSubtitle: String {
        let mMonth = month(day.malayalamMonth)
        let kollYear = day.kollavarshamYear.formatted(.number.grouping(.never))
        return "\(mMonth) \(day.malayalamDay) · Kollavarsham \(kollYear)"
    }

    // MARK: - Metrics grid (2 columns, items paired)

    private var metricsGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
        return LazyVGrid(columns: cols, spacing: 10) {
            // Row 1: Sunrise + Sunset
            metric("Sunrise",    time(day.sunrise),        "sunrise.fill")
            metric("Sunset",     time(day.sunset),         "sunset.fill")
            // Row 2: Main Star + Sunrise Star
            metric("Star (Main)",    star(day.mainNakshatra),    "sparkle")
            metric("Star (Sunrise)", star(day.sunriseNakshatra), "sun.max")
            // Row 3: Tithi + Kollavarsham
            metric("Tithi",       "\(day.tithi.englishName)  \(day.tithi.paksha)", "moonphase.first.quarter")
            metric("Kollavarsham", day.kollavarshamYear.formatted(.number.grouping(.never)), "calendar.badge.clock")
            // Row 4: Rahu Kalam + Gulika Kalam
            metric("Rahu Kalam",   period(day.rahuKalam),   "clock.badge.exclamationmark")
            metric("Gulika Kalam", period(day.gulikaKalam), "clock.arrow.circlepath")
            // Row 5: Yamagandam (left cell) + empty spacer
            metric("Yamagandam", period(day.yamagandam), "clock")
            Color.clear.frame(height: 0)
        }
    }

    @ViewBuilder
    private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Family Events section (shown only when there are events on this day)

    private var familyEventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Family Events", icon: "person.2.fill")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(familyEvents) { event in
                    HStack(spacing: 10) {
                        // Coloured indicator
                        RoundedRectangle(cornerRadius: 2)
                            .fill(event.kind == .birthday ? Color.yellow : Color.yellow.opacity(0.7))
                            .frame(width: 4, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.yellow)
                            Text(event.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Section label (plain, no collapse toggle)

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.medium))
            .padding(.top, 4)
    }

    // MARK: - Helpers

    private func month(_ m: MalayalamMonth) -> String {
        switch languagePreference {
        case .english:   m.englishName
        case .malayalam: m.malayalamName
        case .bilingual: "\(m.englishName) / \(m.malayalamName)"
        }
    }

    private func star(_ n: Nakshatra) -> String {
        switch languagePreference {
        case .english:   n.englishName
        case .malayalam: n.malayalamName
        case .bilingual: "\(n.englishName) / \(n.malayalamName)"
        }
    }

    private func time(_ date: Date) -> String {
        PanchangamFormatters.time(date, timeZone: day.location.timeZone)
    }

    private func period(_ p: TimePeriod) -> String {
        "\(time(p.start)) – \(time(p.end))"
    }
}
