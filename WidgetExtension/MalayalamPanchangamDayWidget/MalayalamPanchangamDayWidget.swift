import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct MalayalamPanchangamDayEntry: TimelineEntry {
    let date: Date
    let snapshot: PanchangamDaySnapshot
}

// MARK: - Provider

struct MalayalamPanchangamDayProvider: TimelineProvider {

    func placeholder(in context: Context) -> MalayalamPanchangamDayEntry {
        MalayalamPanchangamDayEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (MalayalamPanchangamDayEntry) -> Void) {
        completion(MalayalamPanchangamDayEntry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MalayalamPanchangamDayEntry>) -> Void) {
        let entry = MalayalamPanchangamDayEntry(date: .now, snapshot: loadSnapshot())
        // Refresh every 6 hours; WidgetCenter.reloadTimelines is also called
        // by the main app whenever a new calendar is generated.
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: .now)
                    ?? .now.addingTimeInterval(21_600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    // MARK: - Data loading

    private func loadSnapshot() -> PanchangamDaySnapshot {
        // Build candidate URLs: App Group container first, then direct fallback path
        var candidates: [URL] = []

        if let base = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.malayalampanchangam.calendar") {
            candidates.append(
                base
                    .appending(path: "MalayalamPanchangamCalendar", directoryHint: .isDirectory)
                    .appending(path: "WidgetDaySnapshot.json")
            )
        }

        // Direct fallback — works when App Group sandbox read is blocked on dev-signed builds
        let home = FileManager.default.homeDirectoryForCurrentUser
        candidates.append(
            home
                .appendingPathComponent("Library/Group Containers/group.com.malayalampanchangam.calendar/MalayalamPanchangamCalendar/WidgetDaySnapshot.json")
        )

        for url in candidates {
            if let data = try? Data(contentsOf: url),
               let snapshot = try? JSONDecoder().decode(PanchangamDaySnapshot.self, from: data) {
                return snapshot
            }
        }
        return .placeholder
    }
}

// MARK: - Small Widget View

private struct SmallWidgetView: View {
    let s: PanchangamDaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — weekday + icon
            HStack(alignment: .firstTextBaseline) {
                Text(s.weekday.prefix(3))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "moon.stars.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }

            // Gregorian date large
            Text(s.gregorianDate)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 2)

            // Malayalam date
            Text("\(s.malayalamMonth)  \(s.malayalamDay)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.top, 1)

            Spacer(minLength: 4)
            Divider()
            Spacer(minLength: 4)

            // Nakshatra
            Label {
                Text(s.nakshatra)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } icon: {
                Image(systemName: "sparkle")
            }
            .font(.caption2)

            // Rahu Kalam
            Label {
                Text(s.rahuKalam)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } icon: {
                Image(systemName: "clock.badge.exclamationmark.fill")
            }
            .font(.caption2)
            .foregroundStyle(.orange)
            .padding(.top, 1)
        }
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Medium Widget View

private struct MediumWidgetView: View {
    let s: PanchangamDaySnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // LEFT — date block
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                    Text(s.weekday)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(s.gregorianDate)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("\(s.malayalamMonth)  \(s.malayalamDay)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text("KE \(s.kollavarshamYear)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 0)

                Text(s.locationName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Divider()

            // RIGHT — panchangam details
            VStack(alignment: .leading, spacing: 5) {
                detailRow(icon: "sparkle",
                          label: "Nakshatra",
                          value: s.nakshatra)

                detailRow(icon: "moon.circle.fill",
                          label: "Tithi",
                          value: s.tithi)

                detailRow(icon: "sunrise.fill",
                          label: "Sunrise",
                          value: s.sunrise)

                detailRow(icon: "clock.badge.exclamationmark.fill",
                          label: "Rahu",
                          value: s.rahuKalam,
                          valueColor: .orange)
            }
        }
        .padding(.horizontal, 4)
        .containerBackground(.background, for: .widget)
    }

    @ViewBuilder
    private func detailRow(
        icon: String,
        label: String,
        value: String,
        valueColor: Color = .primary
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.tint)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }
}

// MARK: - Entry View (dispatches to size-specific views)

struct MalayalamPanchangamDayWidgetView: View {
    let entry: MalayalamPanchangamDayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(s: entry.snapshot)
        default:
            SmallWidgetView(s: entry.snapshot)
        }
    }
}

// MARK: - Widget Declaration

struct MalayalamPanchangamDayWidget: Widget {
    let kind = "MalayalamPanchangamDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MalayalamPanchangamDayProvider()) { entry in
            MalayalamPanchangamDayWidgetView(entry: entry)
        }
        .configurationDisplayName("Panchangam Day")
        .description("Gregorian and Malayalam date, nakshatra, tithi, sunrise, and Rahu Kalam.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct MalayalamPanchangamWidgetBundle: WidgetBundle {
    var body: some Widget {
        MalayalamPanchangamDayWidget()
    }
}
